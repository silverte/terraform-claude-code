# Org-Foundation 통합 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** AWS Organizations, OU, SCP, 중앙 보안(CloudTrail/GuardDuty/SecurityHub), Transit Gateway, Account Baseline, SSM Export를 기존 프로젝트에 통합

**Architecture:** `/tf-spec`에 프로젝트 타입 선택(org-foundation vs workload) 추가. org-foundation 선택 시 organization.yaml 기반 질문 흐름 → 3단계 분리된 환경(01-organization, 02-security-baseline, 03-shared-networking)으로 코드 생성

**Tech Stack:** Terraform >= 1.5.0, AWS Provider ~> 5.0, AWS Organizations, SCPs, SSM Parameter Store

---

## Task 1: Feature 브랜치 생성

**Files:**
- (git operation only)

**Step 1: 브랜치 생성**
```bash
git checkout -b feature/org-foundation
```

**Step 2: 커밋** (이 단계는 Task 2 이후 일괄)

---

## Task 2: `templates/organization.yaml` 신규 생성

**Files:**
- Create: `templates/organization.yaml`

org-foundation 전체를 커버하는 YAML 템플릿. 기존 템플릿 패턴(enabled: true/false, 한국어 주석, 기본값) 일관 유지.

**섹션 구성:**
1. `organization` - AWS Organizations 기본 설정
2. `organizational_units` - OU 트리 구조
3. `scps` - Service Control Policies
4. `accounts` - 계정 관리/베이스라인
5. `delegated_administrators` - 위임 관리자
6. `centralized_security` - 조직 레벨 보안 서비스 (CloudTrail, GuardDuty, SecurityHub, Config)
7. `shared_networking` - Transit Gateway, RAM 공유, Egress VPC
8. `account_baseline` - 계정 레벨 보안 기본값
9. `ssm_exports` - SSM Parameter Store Export

**주요 설계:**
- `centralized_security`는 기존 `security.yaml`/`monitoring.yaml`과 겹치지만, 조직 레벨(delegated admin, organization trail)에 특화
- `shared_networking`은 TGW 생성 + RAM 공유 포함 (기존 networking.yaml의 TGW는 attachment 용)
- `ssm_exports`에 자동 export 목록 포함

---

## Task 3: `templates/_base.yaml` 수정

**Files:**
- Modify: `templates/_base.yaml`

**변경 내용:**
- `project` 섹션에 `type` 필드 추가: `"workload"` (기본값) | `"org-foundation"`
- org-foundation일 때 `multi_account`가 자동으로 활성화되도록 주석 안내

```yaml
project:
  name: ""
  type: "workload"               # 프로젝트 타입: workload | org-foundation
  description: ""
  environment: "dev"
  region: "ap-northeast-2"
  account_id: ""
```

---

## Task 4: `.claude/commands/tf-spec.md` 수정

**Files:**
- Modify: `.claude/commands/tf-spec.md`

**변경 범위:**
1. **Phase 0 추가** (기존 Phase 1 앞에): 프로젝트 타입 선택
   - AskUserQuestion으로 "조직 기반 설정" vs "워크로드 배포" 선택
   - org-foundation 선택 시 → Phase 1-org로 분기
   - workload 선택 시 → 기존 Phase 1로 진행

2. **Phase 1-org: org-foundation 기본 정보** (신규)
   - Management Account ID (필수)
   - Security Account ID
   - Log Archive Account ID
   - 리전 (기본: ap-northeast-2, us-east-1도 병행)
   - State 설정

3. **Phase 2-org: 조직 구조** (신규)
   - OU 구성: 권장 구조(Core/Infrastructure/Workloads/Sandbox) vs 커스텀
   - 계정 목록: 각 OU에 배치할 계정 이름/이메일/역할

4. **Phase 3-org: SCP** (신규)
   - 기본 SCP 세트 선택 (DenyRoot, AllowedRegions, DenyPublicS3, DenyLeaveOrg)
   - 허용 리전 목록 입력
   - 추가 커스텀 SCP 여부

5. **Phase 4-org: 중앙 보안** (신규)
   - 조직 CloudTrail 활성화 여부
   - GuardDuty 조직 활성화 + 위임 관리자 계정
   - Security Hub 조직 활성화 + 표준 선택
   - Config 조직 활성화 + Aggregator

6. **Phase 5-org: 공유 네트워크** (신규)
   - Transit Gateway 사용 여부
   - TGW 공유 대상 OU/계정 선택
   - Egress VPC 필요 여부 (중앙 NAT)
   - 비전문가: "계정 간 네트워크 연결이 필요합니까?"

7. **Phase 6-org: Account Baseline** (신규)
   - S3 퍼블릭 차단 (기본: true)
   - EBS 기본 암호화 (기본: true)
   - IMDSv2 강제 (기본: true)
   - TerraformExecutionRole 자동 생성

8. **Phase 7-org: SSM Export** (신규)
   - 자동 export 항목 확인 (계정 ID, OU ID, TGW ID, 로깅 버킷 등)
   - SSM prefix 설정 (기본: /org)

9. **Phase 8-org: 명세서 생성 및 확인** (기존 Phase 4-5와 동일 패턴)
   - org-foundation spec 파일 구조로 생성
   - 요약 표시 및 확인

**질문 전략:**
- 비전문가에게는 "권장 구조를 사용하시겠습니까?" → 대부분 기본값 수락
- 전문가에게는 세부 설정 직접 입력 허용
- 환경별 차별화는 없음 (org-foundation은 한 번만 설정)

---

## Task 5: `.claude/commands/tf-generate.md` 수정

**Files:**
- Modify: `.claude/commands/tf-generate.md`

**변경 범위:**

1. **Phase 1 수정**: spec의 `project.type` 확인하여 분기
   - `org-foundation` → org-foundation 생성 로직
   - `workload` (또는 미지정) → 기존 로직

2. **org-foundation 출력 디렉토리 구조** (신규):
   ```
   environments/org-foundation/
   ├── 01-organization/        # Organizations + OU + SCP
   │   ├── main.tf
   │   ├── variables.tf
   │   ├── outputs.tf
   │   ├── versions.tf
   │   ├── locals.tf
   │   ├── backend.hcl
   │   └── terraform.tfvars
   ├── 02-security-baseline/   # CloudTrail, GuardDuty, SecurityHub, Config
   │   └── (same structure)
   └── 03-shared-networking/   # TGW, Egress VPC
       └── (same structure)
   ```

3. **org-foundation 모듈 매핑** (추가):
   ```
   | Spec 카테고리 | 모듈 경로 | 단계 |
   |---|---|---|
   | organization | modules/organization/aws-organization | 01 |
   | organizational_units | modules/organization/organizational-unit | 01 |
   | scps | modules/organization/service-control-policy | 01 |
   | accounts | modules/organization/account-baseline | 01 |
   | delegated_administrators | modules/organization/delegated-admin | 01 |
   | centralized_security.cloudtrail | modules/security/organization-cloudtrail | 02 |
   | centralized_security.guardduty | modules/security/guardduty-org | 02 |
   | centralized_security.security_hub | modules/security/securityhub-org | 02 |
   | centralized_security.config | modules/security/config-aggregator | 02 |
   | shared_networking.transit_gateway | modules/networking/transit-gateway | 03 |
   | shared_networking.ram_share | modules/networking/tgw-ram-share | 03 |
   | shared_networking.egress_vpc | modules/networking/vpc | 03 |
   | ssm_exports | modules/organization/ssm-exporter | 01,02,03 |
   ```

4. **org-foundation Provider 패턴**:
   - 01-organization: Management Account direct (no assume role)
   - 02-security-baseline: Management + Security Account (assume role)
   - 03-shared-networking: Management + Shared Services Account (assume role)

5. **단계 간 의존성 처리**:
   - 02 → 01의 output 참조 (remote state 또는 SSM)
   - 03 → 01, 02의 output 참조
   - `data.terraform_remote_state` 또는 `data.aws_ssm_parameter` 사용

---

## Task 6: `.claude/agents/tf-architect.md` 수정

**Files:**
- Modify: `.claude/agents/tf-architect.md`

**변경 내용:**
- `## Integration with /tf-spec` 섹션에 org-foundation 설계 판단 추가:
  - OU 구조 설계 (워크로드 특성에 따른 OU 배치)
  - SCP 정책 조합 권장
  - TGW 라우팅 테이블 설계 (spoke isolation vs shared access)
  - 계정 간 CIDR 할당 전략 (겹침 방지)
- `## Implementation Phases` 섹션 내용 구체화

---

## Task 7: `CLAUDE.md` 수정

**Files:**
- Modify: `.claude/CLAUDE.md`

**변경 내용:**

1. **핵심 워크플로우** 섹션에 org-foundation 흐름 추가:
   ```
   /tf-spec my-org (조직 기반)  → specs/my-org-spec.yaml
                                       ↓
   /tf-generate specs/my-org-spec.yaml → environments/org-foundation/01-organization/
                                        → environments/org-foundation/02-security-baseline/
                                        → environments/org-foundation/03-shared-networking/
   ```

2. **프로젝트 구조** 업데이트:
   - `templates/organization.yaml` 추가
   - `environments/org-foundation/` 구조 추가
   - `modules/organization/` 카테고리 추가

3. **State 파일 경로** 업데이트:
   ```
   s3://{bucket}/
   ├── org-foundation/organization/terraform.tfstate
   ├── org-foundation/security-baseline/terraform.tfstate
   ├── org-foundation/shared-networking/terraform.tfstate
   ├── dev/terraform.tfstate
   ├── staging/terraform.tfstate
   └── prod/terraform.tfstate
   ```

4. **사용 예시** 추가:
   ```bash
   # 조직 기반 설정
   /project:tf-spec my-org
   /project:tf-generate specs/my-org-spec.yaml

   # 워크로드 배포
   /project:tf-spec my-web-service
   /project:tf-generate specs/my-web-service-spec.yaml
   ```

---

## Task 8: 최종 검증

**Step 1: YAML 문법 검증**
```bash
python3 -c "import yaml; yaml.safe_load(open('templates/organization.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('templates/_base.yaml'))"
```

**Step 2: 전체 파일 일관성 확인**
- organization.yaml의 섹션이 tf-spec.md의 질문 흐름과 매칭되는지
- tf-generate.md의 모듈 매핑이 organization.yaml 구조와 일치하는지
- CLAUDE.md의 문서가 실제 변경사항을 반영하는지

**Step 3: 커밋**
```bash
git add templates/organization.yaml templates/_base.yaml
git add .claude/commands/tf-spec.md .claude/commands/tf-generate.md
git add .claude/agents/tf-architect.md .claude/CLAUDE.md
git add docs/plans/2026-02-15-org-foundation-integration-plan.md
git commit -m "feat: integrate org-foundation into project"
```
