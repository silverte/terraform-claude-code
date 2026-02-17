# Comprehensive Terraform Review

보안, 비용, 모범 사례에 대한 종합적인 Terraform 코드 리뷰를 수행합니다.

## Workflow Position
이 커맨드는 개별 워크플로우(`/tf-spec` → `/tf-generate` → **`/tf-review`** → `/tf-plan`)에서 코드 품질 검증 단계입니다.
`/tf-generate`로 코드가 생성된 후, `/tf-plan` 전에 실행하세요.

> **참고**: `/tf-build`를 사용하면 코드 생성과 리뷰가 통합 실행됩니다.
> 이 커맨드는 기존 코드를 독립적으로 리뷰할 때 사용합니다.

## Usage
```
/tf-review <path>
```

## Arguments
- **path**: 리뷰할 경로 (모듈 또는 환경 디렉토리)

## Examples
```
/tf-review modules/vpc
/tf-review environments/prod
/tf-review .
```

## MCP 서버 활용

이 커맨드는 메인 세션에서 실행되므로 MCP 도구를 직접 사용할 수 있습니다.
**중요**: tf-security-reviewer, tf-cost-analyzer 서브에이전트는 MCP 도구에 접근할 수 없습니다. 메인 세션에서 MCP로 수집한 정보를 서브에이전트 프롬프트에 포함하여 전달하세요.

### 리뷰 시작 전 MCP 수집 (Phase 1 이전)
```
1. RunCheckovScan(working_directory="{path}") → Checkov 보안 스캔 결과 수집
2. 주요 리소스 타입 식별 후 SearchAwsProviderDocs 호출 → deprecated 속성 확인
   예: S3 모듈 → SearchAwsProviderDocs("aws_s3_bucket") → ACL deprecated 여부
   예: EC2 모듈 → SearchAwsProviderDocs("aws_instance") → metadata_options 권장값
```

### 서브에이전트 호출 시 MCP 결과 전달
```
Task(subagent_type="tf-security-reviewer", prompt="""
{path}의 Terraform 코드를 보안 리뷰해주세요.

## Checkov 스캔 결과 (MCP RunCheckovScan)
{RunCheckovScan 결과}

## Provider 속성 정보 (MCP SearchAwsProviderDocs)
{deprecated/보안 관련 속성 정보}

위 결과를 참고하여 종합 보안 리뷰를 수행하세요.
""")
```

## Review Process

### Phase 1: Security Review
**tf-security-reviewer 서브에이전트 호출**

**Well-Architected Security MCP 호출**: Security Pillar 기반 평가 체크리스트를 조회하여 리뷰 기준으로 활용합니다.

#### IAM 정책 검토
- 와일드카드 사용 여부
- 최소 권한 원칙 준수
- Trust Policy 범위

#### 네트워크 보안 검토
- Security Group 규칙
- NACL 설정
- VPC Flow Logs

#### 암호화 설정 검토
- S3 버킷 암호화
- EBS 암호화
- RDS 암호화
- KMS 키 관리

#### 컴플라이언스 검토
- CloudTrail 설정
- Config Rules
- GuardDuty

### Phase 2: Cost Analysis
**tf-cost-analyzer 서브에이전트 호출**

#### 리소스 비용 분석
- Compute (EC2, Lambda, EKS)
- Storage (S3, EBS, EFS)
- Database (RDS, DynamoDB)
- Network (NAT, TGW, Data Transfer)

#### 최적화 기회 식별
- Right-sizing 후보
- Reserved/Savings Plans 후보
- Spot Instance 후보
- 스토리지 티어링

### Phase 3: Code Quality
**자동화된 도구 실행 + Terraform MCP로 보안 스캔 및 deprecated 속성 검증**

#### Step 1: MCP 보안 스캔 (우선 사용)
Terraform MCP의 `RunCheckovScan` 도구로 보안/정책 스캔을 실행합니다:
```
RunCheckovScan(working_directory="{path}")
```
MCP 스캔이 실패하거나 결과가 불충분한 경우에만 로컬 도구를 사용합니다.

#### Step 2: 기본 검증 (항상 실행)
```bash
# 포맷팅 검사
terraform fmt -check -recursive $PATH

# 문법 검증
cd $PATH && terraform validate
```

#### Step 3: 로컬 도구 (설치된 경우에만)
각 도구의 설치 여부를 확인한 후 실행합니다:
```bash
# tflint 설치 확인 후 실행
which tflint && tflint --recursive $PATH

# tfsec 설치 확인 후 실행 (MCP RunCheckovScan이 이미 커버하므로 보충용)
which tfsec && tfsec $PATH --minimum-severity MEDIUM
```
설치되지 않은 도구는 건너뛰고 MCP 스캔 결과로 대체합니다.

### Phase 4: Best Practices
**수동 검토 항목**

#### 모듈 구조
- [ ] 표준 파일 구조 준수 (main.tf, variables.tf, outputs.tf, versions.tf, locals.tf)
- [ ] 적절한 추상화 수준
- [ ] 재사용 가능성
- [ ] 테스트 파일 존재 (`tests/main.tftest.hcl`)

#### HCL 스타일 (HashiCorp Style Guide 기반)
- [ ] 블록 내부 순서: meta-args → args → blocks → tags → lifecycle
- [ ] `for_each` 사용 (복수 리소스), `count`는 조건부 생성에만 사용
- [ ] 등호(`=`) 정렬 (연속된 인수)
- [ ] 리소스 이름: 설명적 명사, snake_case (리소스 타입 중복 금지)
- [ ] Provider `default_tags` 블록 사용

#### 변수 정의
- [ ] 모든 변수에 description + type
- [ ] 주요 변수에 validation 블록
- [ ] sensitive 플래그 적용 (패스워드, 키)
- [ ] 변수 순서: required → optional → sensitive (각각 알파벳순)
- [ ] boolean 변수에 `enable_` 접두사

#### 출력 정의
- [ ] 필요한 출력 제공 (id, arn 등 주요 속성)
- [ ] 설명적인 description
- [ ] 모듈 합성 가능하도록 핵심 속성 출력

#### 문서화
- [ ] README.md 존재
- [ ] 사용 예제 제공 (examples/basic, examples/complete)
- [ ] CHANGELOG.md 관리

#### 태깅
- [ ] 필수 태그 적용 (Project, Environment, ManagedBy, Owner, CostCenter)
- [ ] 일관된 태깅 전략
- [ ] Provider `default_tags`와 리소스별 `tags` 조합

### Phase 5: Documentation Review

#### README 검토
- 모듈/환경 설명
- 사용 방법
- 변수 테이블
- 출력 테이블

#### 예제 검토
- 기본 예제 존재
- 전체 옵션 예제 존재
- 예제 실행 가능

## Output Format

```markdown
# Terraform Review Report

## 📋 Summary

| Category | Status | Findings |
|----------|--------|----------|
| Security | 🔴/🟡/🟢 | X issues |
| Cost | 🔴/🟡/🟢 | X issues |
| Code Quality | 🔴/🟡/🟢 | X issues |
| Best Practices | 🔴/🟡/🟢 | X issues |
| Documentation | 🔴/🟡/🟢 | X issues |

**Overall Score: X/100**

---

## 🔒 Security Review

### Critical Findings
1. **[CRITICAL]** Finding title
   - Resource: `resource_type.name`
   - File: `path/to/file.tf:line`
   - Issue: Description
   - Remediation: 
   ```hcl
   # Fixed code
   ```

### High Findings
...

### Recommendations
1. Immediate action required
2. Short-term improvements
3. Long-term enhancements

---

## 💰 Cost Analysis

### Current Estimated Cost
| Resource Type | Monthly Cost |
|--------------|--------------|
| Compute | $XXX |
| Storage | $XXX |
| Network | $XXX |
| **Total** | **$XXX** |

### Optimization Opportunities
| Opportunity | Current | Optimized | Savings |
|-------------|---------|-----------|---------|
| Right-size EC2 | $XXX | $XXX | $XXX |
| Reserved Instances | $XXX | $XXX | $XXX |

**Total Potential Savings: $XXX/month**

---

## 🔧 Code Quality

### Automated Scan Results
| Tool | Status | Issues |
|------|--------|--------|
| terraform fmt | ✅/❌ | X |
| terraform validate | ✅/❌ | X |
| tflint | ✅/❌ | X |
| tfsec | ✅/❌ | X |
| checkov | ✅/❌ | X |

### Issues Found
1. Issue description
   - File: `path/to/file.tf`
   - Fix: Description

---

## 📚 Best Practices

### Module Structure: ✅/❌
- [x] Standard file structure
- [ ] Issue found

### Variables: ✅/❌
- [x] Descriptions provided
- [ ] Issue found

### Documentation: ✅/❌
- [x] README exists
- [ ] Issue found

---

## 🎯 Action Items

### Priority 1 (Immediate)
- [ ] Fix critical security issues
- [ ] Address high-severity findings

### Priority 2 (This Sprint)
- [ ] Implement cost optimizations
- [ ] Fix code quality issues

### Priority 3 (Backlog)
- [ ] Improve documentation
- [ ] Enhance test coverage

---

## 📎 Appendix

### Files Reviewed
- file1.tf
- file2.tf
- ...

### Tools Used
- tfsec v1.x.x
- checkov v3.x.x
- tflint v0.x.x
- infracost v0.x.x
```

## Severity Definitions

| Level | Color | Description | 자동 수정 |
|-------|-------|-------------|-----------|
| Critical | 🔴 | 즉시 수정 필요, 배포 차단 | 자동 수정 코드 생성 → 사용자 승인 후 적용 |
| High | 🟠 | 프로덕션 전 수정 필요 | 자동 수정 코드 생성 → 사용자 승인 후 적용 |
| Medium | 🟡 | 다음 스프린트에 수정 | 리포트에 수정 방법 안내만 |
| Low | 🟢 | 개선 권장 | 리포트에 개선 제안만 |

---

## Phase 6: 자동 수정 (Auto-Fix)

> **`/tf-build`와의 정책 차이**: `/tf-build`의 Phase 4는 방금 생성된 코드를 대상으로 하므로 사용자 확인 없이 자동 수정합니다.
> `/tf-review`는 기존 코드(사용자가 수정했을 수 있는 코드)를 대상으로 하므로 반드시 사용자 승인을 받습니다.

**중요**: Phase 1-5의 분석은 서브에이전트(tf-security-reviewer, tf-cost-analyzer)에 위임하지만, Phase 6의 코드 수정은 **메인 세션에서 직접 수행**합니다. 서브에이전트는 read-only(Write/Edit 금지)이므로 코드를 수정할 수 없습니다.

리뷰 리포트 출력 후, Critical/High 이슈가 있으면 자동 수정 프로세스를 실행합니다.

### Step 1: 수정 대상 확인

리뷰 결과에서 Critical/High 이슈를 추출하여 수정 대상 목록을 생성합니다.

```
수정 대상: 3건 (Critical: 1, High: 2)

| # | Severity | Issue | File | 수정 가능 |
|---|----------|-------|------|----------|
| 1 | CRITICAL | S3 퍼블릭 접근 차단 미설정 | modules/storage/s3/main.tf:15 | ✅ 자동 |
| 2 | HIGH | Security Group 0.0.0.0/0 인바운드 | environments/dev/main.tf:42 | ✅ 자동 |
| 3 | HIGH | EBS 암호화 미설정 | modules/compute/ec2/main.tf:8 | ✅ 자동 |
```

### Step 2: 사용자 승인 요청

AskUserQuestion으로 수정 범위를 확인합니다.

질문: "Critical/High 이슈 3건이 발견되었습니다. 어떻게 처리하시겠습니까?"

선택지:
- **전체 자동 수정**: 모든 Critical/High 이슈를 자동 수정합니다 (각 수정 전 diff를 보여드립니다)
- **선택 수정**: 수정할 이슈를 선택합니다
- **리포트만 확인**: 수정하지 않고 리포트만 확인합니다

### Phase 6 수정 시 MCP 활용
자동 수정 코드 생성 시 `SearchAwsProviderDocs`로 올바른 속성을 확인한 후 수정합니다:
```
예: S3 public access block 추가 시 → SearchAwsProviderDocs("aws_s3_bucket_public_access_block")
예: EBS 암호화 설정 시 → SearchAwsProviderDocs("aws_ebs_encryption_by_default")
```

### Step 3: 수정 코드 생성 및 적용

각 이슈에 대해 순서대로:

1. **수정 코드 생성**: 이슈에 맞는 수정 코드를 생성합니다
   - Terraform MCP로 올바른 리소스 속성을 조회하여 정확한 수정 코드 작성
   - 기존 코드의 스타일/패턴을 유지하면서 수정

2. **diff 표시**: 수정 전후 차이를 보여줍니다
   ```diff
   # modules/storage/s3/main.tf
   + resource "aws_s3_bucket_public_access_block" "this" {
   +   bucket = aws_s3_bucket.this.id
   +
   +   block_public_acls       = true
   +   block_public_policy     = true
   +   ignore_public_acls      = true
   +   restrict_public_buckets = true
   + }
   ```

3. **사용자 확인**: 각 수정사항에 대해 승인 여부를 확인합니다
   - "적용" → Edit 도구로 코드 수정
   - "건너뛰기" → 다음 이슈로 이동
   - "수정 변경" → 사용자가 원하는 방향으로 수정 코드 재생성

4. **적용 후 검증**: 수정 적용 후 해당 이슈에 대해 재검증
   ```bash
   terraform fmt -check
   terraform validate
   ```

### Step 4: 수정 결과 요약

모든 수정이 완료되면 결과를 출력합니다.

```
## 수정 완료 요약

| # | Issue | 상태 |
|---|-------|------|
| 1 | S3 퍼블릭 접근 차단 | ✅ 수정 완료 |
| 2 | Security Group 0.0.0.0/0 | ✅ 수정 완료 |
| 3 | EBS 암호화 미설정 | ⏭️ 건너뜀 (사용자 선택) |

수정된 파일:
- modules/storage/s3/main.tf
- environments/dev/main.tf

남은 이슈: Medium 2건, Low 1건 (리포트 참조)

다음 단계:
1. 수정된 코드 확인: /tf-review <path> (재검증)
2. Plan 확인: /tf-plan <env>
```

### 자동 수정 불가능한 경우

다음 이슈는 자동 수정 대신 상세 가이드를 제공합니다:

| 유형 | 이유 | 대응 |
|------|------|------|
| 아키텍처 변경 필요 | 리소스 구조 재설계 필요 | tf-architect 에이전트 호출 제안 |
| 비용 최적화 | 인스턴스 타입 변경 등 비즈니스 판단 필요 | 옵션 목록과 비용 비교 제공 |
| 외부 의존성 | IAM 정책, 계정 설정 등 Terraform 외부 작업 | 수동 조치 가이드 제공 |
| 삭제가 필요한 경우 | 리소스 삭제는 위험 | 경고와 함께 수동 확인 요청 |

---

## Post-Review Actions

### Critical/High 이슈가 있는 경우
1. Phase 6(자동 수정)을 통해 코드 수정
2. 수정 후 `/tf-review`를 재실행하여 이슈 해결 확인
3. 모든 Critical/High 해결 후 `/tf-plan` 진행

### Medium/Low 이슈만 있는 경우
1. 리포트의 수정 가이드를 참고하여 필요 시 수동 수정
2. `/tf-plan` 바로 진행 가능

### 이슈가 없는 경우
1. `/tf-plan` 바로 진행
