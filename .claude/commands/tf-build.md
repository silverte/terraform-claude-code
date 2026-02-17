# Terraform Build - 코드 생성 + 품질 검증 통합

YAML 명세서(spec.yaml)를 읽어 Terraform 코드를 생성하고, 즉시 보안/비용/품질 검증까지 한번에 수행합니다.

## Workflow Position
`/tf-spec` → **`/tf-build`** → `/tf-plan`

## Usage
```
/tf-build <spec-file>
```

## Arguments
- **spec-file**: 명세서 경로 (예: specs/my-web-service-spec.yaml)
- **--only** (선택): 특정 카테고리만 재생성 (예: `--only networking,compute`)
  - Argument Parsing은 `/tf-generate`의 Argument Parsing 섹션과 동일한 규칙을 따릅니다
  - org-foundation은 `--only` 미지원 (단계 간 의존성)

## 기존 커맨드와의 관계
```
/tf-build = /tf-generate + /tf-review (통합, 최적화)

기존 커맨드는 독립적으로 유지:
- /tf-generate : 코드만 생성하고 싶을 때
- /tf-review   : 기존 코드를 리뷰할 때 (이미 있는 코드 검토)
- /tf-build    : 새 코드 생성 + 리뷰를 한번에 (권장)
```

## Execution Steps

### Phase 1: 명세서 파싱 및 검증

1. spec 파일을 읽고 YAML 파싱
2. `project.type` 필드 확인:
   - `org-foundation` → **org-foundation 흐름**으로 분기 (아래 별도 섹션)
   - `workload` (또는 미지정) → **워크로드 흐름**으로 진행
3. 필수 필드 존재 여부 확인:
   - 공통: `project.name`, `project.region`, `project.account_id`
   - 워크로드: `project.environment`, `owner.team`, `owner.cost_center`
   - org-foundation: `project.account_id` (Management Account)
4. 값 유효성 검증:
   - CIDR 형식, 리전 형식, 환경 값, 계정 ID 형식
5. 오류 발견 시 사용자에게 보고하고 수정 안내

---

## 워크로드 흐름 (project.type: "workload")

### Phase 2: MCP 데이터 일괄 수집

spec에서 enabled된 카테고리의 핵심 리소스를 추출하고, MCP로 한번에 조회합니다.
이 데이터는 Phase 3(모듈 생성)과 Phase 5(심층 리뷰) 모두에서 재사용합니다.

```
1. spec에서 사용할 리소스 목록 추출
   예: networking.vpc → aws_vpc, aws_subnet, aws_internet_gateway, aws_nat_gateway
   예: compute.ecs → aws_ecs_cluster, aws_ecs_service, aws_ecs_task_definition
   예: database.rds → aws_db_instance, aws_db_subnet_group

2. SearchAwsProviderDocs 일괄 호출 (각 리소스에 대해)
   → 속성 정보, deprecated 여부, 보안 관련 설정 수집

3. 복잡한 패턴이 필요한 경우 search_documentation 호출
   예: 멀티 어카운트 AssumeRole → search_documentation("cross account assume role")
```

**핵심**: 이 단계에서 수집한 MCP 데이터를 변수에 저장하여, 이후 Phase에서 중복 호출을 방지합니다.

### Phase 3: 코드 생성

Phase 2에서 수집한 MCP 데이터를 활용하여 코드를 생성합니다.

#### Step 1: 출력 디렉토리 준비
```bash
TARGET_DIR="environments/{project.environment}"
mkdir -p $TARGET_DIR
```
이미 존재하면 사용자에게 덮어쓰기 여부 확인.

#### Step 2: 모듈 확인 및 생성
spec에서 enabled된 각 카테고리에 대해:
1. `modules/` 에 해당 모듈이 있는지 확인
2. 없으면 tf-module-developer 에이전트를 호출하여 모듈 생성
3. 있으면 기존 모듈 재사용

**여러 모듈 생성이 필요한 경우 병렬 호출**:
```
# 독립적인 모듈은 동시에 생성 (단일 메시지에서 여러 Task 호출)
Task(subagent_type="tf-module-developer", prompt="VPC 모듈 생성... \n## MCP 리소스 속성\n{Phase 2 결과}")
Task(subagent_type="tf-module-developer", prompt="RDS 모듈 생성... \n## MCP 리소스 속성\n{Phase 2 결과}")
Task(subagent_type="tf-module-developer", prompt="ECS 모듈 생성... \n## MCP 리소스 속성\n{Phase 2 결과}")
```

워크로드 모듈 매핑은 `/tf-generate`와 동일한 규칙을 따릅니다.

#### Step 3: 환경 파일 생성
`/tf-generate` Phase 4와 동일하게 아래 파일들을 생성합니다:
- `versions.tf` - Terraform/Provider 버전
- `providers.tf` - Provider 설정 (싱글/멀티 어카운트)
- `locals.tf` - 공통 태그, name_prefix
- `variables.tf` - spec 기반 변수 (description + type + validation)
- `main.tf` - 모듈 호출
- `outputs.tf` - 모듈 출력 노출
- `backend.hcl` - State 백엔드
- `terraform.tfvars` - 변수 값

### Phase 4: 품질 게이트 (자동 수정)

생성 직후 자동으로 검증하고 수정합니다.

**자동 수정 정책 (`/tf-build` 전용)**:
방금 생성한 코드이므로 Critical/High 이슈는 사용자 확인 없이 바로 수정합니다.

> **적용 범위**: 이 정책은 `/tf-build`로 방금 생성된 코드에만 적용됩니다.
> 기존 코드를 리뷰할 때는 `/tf-review`를 사용하며, 사용자 승인이 필요합니다.
> **근거**: 방금 생성된 코드는 아직 사용자가 커스터마이징하지 않았으므로 자동 수정이 안전합니다.

#### Step 1: 포맷팅 및 검증
```bash
cd environments/{env}
terraform fmt -recursive
terraform validate
```

#### Step 2: MCP 보안 스캔
```
RunCheckovScan(working_directory="environments/{env}")
```
생성된 모듈도 각각 스캔:
```
RunCheckovScan(working_directory="modules/{category}/{name}")
```

#### Step 3: Critical/High 이슈 자동 수정
Checkov 결과에서 Critical/High 이슈가 발견되면:
1. Phase 2에서 수집한 MCP 데이터를 참고하여 올바른 속성 확인
2. Edit 도구로 직접 수정 (사용자 확인 없이)
3. 수정 후 재검증 (`terraform fmt` + `terraform validate`)
4. 자동 수정 내역을 Phase 6 리포트에 포함

**자동 수정 범위** (방금 생성한 코드에 한정):
- S3 퍼블릭 접근 차단, 암호화 설정
- Security Group 과도한 인바운드 규칙
- EBS/RDS 암호화 미설정
- CloudWatch 로깅 미설정
- IMDSv2 미강제 등

**자동 수정하지 않는 경우** (리포트에 안내만):
- 아키텍처 변경이 필요한 이슈
- 비즈니스 판단이 필요한 비용 최적화
- 리소스 삭제가 필요한 경우

#### Step 4: 스타일 규칙 검증
`.claude/references/_validation-checklist.md`를 Read 도구로 읽어 "스타일 규칙 검증" 체크리스트를 적용합니다.
위반 항목이 있으면 직접 수정합니다.

### Phase 5: 심층 리뷰 (병렬)

보안과 비용 리뷰를 동시에 실행합니다.
**두 에이전트를 단일 메시지에서 병렬 호출**합니다.

```
# 병렬 실행: 보안 리뷰 + 비용 분석
Task(subagent_type="tf-security-reviewer", prompt="""
environments/{env}의 Terraform 코드를 보안 리뷰해주세요.

## Checkov 스캔 결과 (Phase 4)
{RunCheckovScan 결과}

## Provider 속성 정보 (Phase 2 MCP)
{Phase 2에서 수집한 보안 관련 속성}

## 자동 수정된 항목 (Phase 4)
{자동 수정 내역 - 이미 해결된 이슈는 제외}
""")

Task(subagent_type="tf-cost-analyzer", prompt="""
environments/{env}의 Terraform 코드 비용을 분석해주세요.

## 리소스 목록
{spec에서 추출한 리소스 요약}

## Provider 속성 정보 (Phase 2 MCP)
{Phase 2에서 수집한 인스턴스/스토리지 관련 속성}
""")
```

### Phase 6: 최종 리포트

Phase 4(자동 수정) + Phase 5(심층 리뷰) 결과를 통합하여 출력합니다.

```markdown
# Terraform Build Report

## 코드 생성 완료

### 프로젝트: {name}
### 타입: 워크로드 배포
### 환경: {env}
### 리전: {region}

---

## 생성된 파일
| 파일 | 설명 |
|------|------|
| environments/{env}/versions.tf | Terraform/Provider 버전 |
| environments/{env}/providers.tf | Provider 설정 |
| ... | ... |

## 생성된 모듈
| 모듈 | 경로 | 상태 |
|------|------|------|
| VPC | modules/networking/vpc | 신규 생성 |
| RDS | modules/database/rds | 기존 재사용 |
| ... | ... | ... |

---

## 📋 품질 검증 결과

| Category | Status | Findings |
|----------|--------|----------|
| Security | 🔴/🟡/🟢 | X issues (Y auto-fixed) |
| Cost | 🔴/🟡/🟢 | X issues |
| Code Quality | 🟢 | Passed |

**Overall Score: X/100**

---

## ✅ 자동 수정된 항목
| # | Severity | Issue | File | 상태 |
|---|----------|-------|------|------|
| 1 | CRITICAL | S3 퍼블릭 접근 차단 | modules/storage/s3/main.tf | ✅ 자동 수정됨 |
| 2 | HIGH | EBS 암호화 미설정 | modules/compute/ec2/main.tf | ✅ 자동 수정됨 |

---

## 🔒 보안 리뷰 (tf-security-reviewer)
{Phase 5 보안 리뷰 결과 요약}

## 💰 비용 분석 (tf-cost-analyzer)
{Phase 5 비용 분석 결과 요약}

---

## 🎯 Action Items (남은 이슈)

### Medium
1. [MEDIUM] Issue description → 수정 가이드

### Low
1. [LOW] Issue description → 개선 제안

---

## 다음 단계
1. terraform.tfvars 값 확인
2. /tf-plan {env}
```

---

## org-foundation 흐름 (project.type: "org-foundation")

org-foundation은 3단계 디렉토리에 대해 Phase 2~5를 반복합니다.

### Phase 2-org: MCP 데이터 일괄 수집

3단계 전체에 필요한 리소스를 한번에 수집합니다:
```
01-organization: aws_organizations_organization, aws_organizations_organizational_unit,
                 aws_organizations_policy, aws_ssm_parameter
02-security:     aws_cloudtrail, aws_guardduty_detector, aws_securityhub_account,
                 aws_config_configuration_aggregator
03-networking:   aws_ec2_transit_gateway, aws_ram_resource_share, aws_vpc
```

복잡한 패턴 확인:
```
search_documentation("delegated administrator setup")
search_documentation("organization trail s3 bucket policy")
search_documentation("transit gateway cross account")
```

### Phase 3-org: 코드 생성

3단계 디렉토리를 생성하고, 각 단계별 모듈과 환경 파일을 생성합니다.
```bash
mkdir -p environments/org-foundation/01-organization
mkdir -p environments/org-foundation/02-security-baseline
mkdir -p environments/org-foundation/03-shared-networking
```

모듈 매핑 규칙과 환경 파일 생성은 `/tf-generate`의 org-foundation 흐름과 동일합니다.
여러 모듈이 필요하면 tf-module-developer를 병렬 호출합니다.

### Phase 4-org: 품질 게이트 (자동 수정)

3단계 각각에 대해 검증 및 자동 수정:
`.claude/references/_validation-checklist.md`의 "org-foundation 검증 경로" 섹션을 Read 도구로 읽어 각 단계별 검증을 실행합니다.

```
# 각 단계별 Checkov 스캔
RunCheckovScan(working_directory="environments/org-foundation/01-organization")
RunCheckovScan(working_directory="environments/org-foundation/02-security-baseline")
RunCheckovScan(working_directory="environments/org-foundation/03-shared-networking")
```

Critical/High 이슈 자동 수정 (워크로드 Phase 4와 동일 정책).

### Phase 5-org: 심층 리뷰 (병렬)

보안/비용 리뷰를 병렬 실행 (리뷰 대상은 전체 org-foundation 디렉토리):
```
Task(subagent_type="tf-security-reviewer", prompt="environments/org-foundation/ 전체 보안 리뷰...")
Task(subagent_type="tf-cost-analyzer", prompt="environments/org-foundation/ 전체 비용 분석...")
```

### Phase 6-org: 최종 리포트

워크로드 Phase 6과 동일한 형식에 단계별 구조를 추가:
```markdown
## 생성된 단계
| 단계 | 경로 | 내용 |
|------|------|------|
| 01 | environments/org-foundation/01-organization/ | Organizations, OU, SCP |
| 02 | environments/org-foundation/02-security-baseline/ | CloudTrail, GuardDuty, SecurityHub |
| 03 | environments/org-foundation/03-shared-networking/ | Transit Gateway, Egress VPC |

## 다음 단계
1. 각 단계의 terraform.tfvars 값 확인
2. /tf-plan management (순서대로 Plan 확인)
```

---

## MCP 서버 활용

이 커맨드는 메인 세션에서 실행되므로 MCP 도구를 직접 사용합니다.
**중요**: tf-module-developer, tf-security-reviewer, tf-cost-analyzer 서브에이전트는 MCP에 접근할 수 없습니다. Phase 2에서 수집한 MCP 데이터를 프롬프트에 포함하여 전달합니다.

### 사용하는 MCP 도구

| 도구 | Phase | 용도 |
|------|-------|------|
| `SearchAwsProviderDocs` | Phase 2 | 리소스 속성 일괄 조회 |
| `search_documentation` | Phase 2 | 복잡한 패턴 확인 |
| `RunCheckovScan` | Phase 4 | 보안/정책 스캔 |
| `SearchAwsProviderDocs` | Phase 4 | 자동 수정 시 올바른 속성 확인 |

### tf-module-developer 호출 시 프롬프트 구성
```
Task(subagent_type="tf-module-developer", prompt="""
{spec에서 추출한 모듈 요구사항}

## MCP에서 조회한 리소스 속성 (참고)
{Phase 2 SearchAwsProviderDocs 결과 요약}

## 기존 모듈 패턴 참고
{기존 modules/ 디렉토리의 패턴}
""")
```

## Code Generation Rules

`.claude/references/_code-generation-rules.md`를 Read 도구로 읽어 모든 규칙을 적용합니다.
