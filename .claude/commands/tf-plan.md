# Terraform Plan for Multi-Account

지정된 계정과 환경에 대해 terraform plan을 실행합니다.

## Workflow Position
이 커맨드는 워크플로우의 마지막 검증 단계입니다.
- 권장: `/tf-spec` → `/tf-build` → **`/tf-plan`**
- 개별: `/tf-spec` → `/tf-generate` → `/tf-review` → **`/tf-plan`**

`/tf-build` 또는 `/tf-generate`로 코드가 생성된 후 실행하세요.

## Usage
```
/tf-plan <target>
```

## Arguments
- **target**: 실행 대상
  - 워크로드: `dev` | `staging` | `prod`
  - org-foundation: `management` (01→02→03 순서대로 실행)
  - org-foundation 개별: `management/01` | `management/02` | `management/03`

## Examples
```
/tf-plan dev                  # environments/dev/ plan
/tf-plan prod                 # environments/prod/ plan
/tf-plan management           # org-foundation 3단계 순차 plan
/tf-plan management/01        # 01-organization만 plan
```

## Argument Parsing

$ARGUMENTS에서 대상을 파싱합니다:
```
입력: "dev"
→ type: "workload"
→ target_dir: "environments/dev"

입력: "management"
→ type: "org-foundation"
→ target_dirs: [
    "environments/org-foundation/01-organization",
    "environments/org-foundation/02-security-baseline",
    "environments/org-foundation/03-shared-networking"
  ]

입력: "management/02"
→ type: "org-foundation-single"
→ target_dir: "environments/org-foundation/02-security-baseline"
```

**매핑 규칙:**
| 입력 | 디렉토리 |
|------|----------|
| `dev` / `staging` / `prod` | `environments/{target}/` |
| `management` | `environments/org-foundation/01-*`, `02-*`, `03-*` 순차 |
| `management/01` | `environments/org-foundation/01-organization/` |
| `management/02` | `environments/org-foundation/02-security-baseline/` |
| `management/03` | `environments/org-foundation/03-shared-networking/` |

## Execution Steps

### Phase 0: 사전 검증

1. **대상 디렉토리 존재 확인**
   ```bash
   ls environments/{target}/
   ```
   - 디렉토리가 없으면 오류 메시지: "디렉토리가 존재하지 않습니다. `/tf-build` 또는 `/tf-generate`를 먼저 실행하세요."

2. **도구 가용성 확인**
   ```bash
   terraform version
   ```
   - terraform이 없으면 설치 안내 후 중단

3. **필수 파일 확인**: `versions.tf`, `variables.tf`, `backend.hcl` 존재 여부

### Phase 1: 워크로드 Plan (dev / staging / prod)

단일 디렉토리에 대해 Plan을 실행합니다.

#### Step 1: Terraform Init
```bash
cd environments/{target}
terraform init -backend-config=backend.hcl -reconfigure
```

#### Step 2: Terraform Plan
```bash
terraform plan -var-file=terraform.tfvars -out=tfplan
```

#### Step 3: Plan 결과 분석
변경 사항을 분석하여 요약 출력합니다.

#### Step 4: 보안 스캔 (선택)
MCP `RunCheckovScan` 도구를 사용하여 보안 스캔을 수행합니다.
로컬 도구가 있는 경우 추가로 실행:
```bash
# tfsec 설치 확인 후 실행
which tfsec && tfsec . --minimum-severity HIGH
```

#### Step 5: 비용 추정 (선택)
```bash
# infracost 설치 확인 후 실행
which infracost && infracost breakdown --path . --format table
```

### Phase 2: org-foundation Plan (management)

3단계를 **순서대로** Plan합니다. 각 단계는 이전 단계에 의존합니다.

#### Step 1: 01-organization Plan
```bash
cd environments/org-foundation/01-organization
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -var-file=terraform.tfvars -out=tfplan
```
- Plan 결과 요약 출력
- **실패 시**: 오류 분석 후 중단 (02, 03 진행 불가)

#### Step 2: 02-security-baseline Plan
```bash
cd environments/org-foundation/02-security-baseline
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -var-file=terraform.tfvars -out=tfplan
```
- Plan 결과 요약 출력
- **주의**: 01이 아직 apply되지 않았으면 remote_state/SSM 참조 오류 발생 가능
  - 이 경우 안내: "01-organization을 먼저 apply한 후 다시 시도하세요"

#### Step 3: 03-shared-networking Plan (디렉토리 존재 시에만)
```bash
cd environments/org-foundation/03-shared-networking
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -var-file=terraform.tfvars -out=tfplan
```
- 디렉토리가 없으면 건너뛰기 (TGW 비활성화 시 생성되지 않음)

#### Step 4: 전체 요약
3단계 Plan 결과를 통합하여 요약 출력합니다.

## Output Format

### 워크로드 Plan 출력
```
## Terraform Plan Summary

### Target: {target}
### Directory: environments/{target}/

### Changes
- Add: X resources
- Change: X resources
- Destroy: X resources

### Key Changes
1. {resource_type}.{name} - {action} - {reason}
2. ...

### Security Scan Results (Checkov)
- Passed: X
- Failed: X
- Skipped: X

### Estimated Cost Impact (infracost 설치 시)
- Current: $XXX/month
- Projected: $XXX/month
- Difference: +$XX/month

### Next Steps
- Plan 내용 확인 후 CI/CD 파이프라인에서 apply 실행
- 주의: `terraform apply`는 직접 실행하지 마세요 (CLAUDE.md 금지사항)
```

### org-foundation Plan 출력
```
## Terraform Plan Summary - org-foundation

### 01-organization
- Add: X resources | Change: X | Destroy: X
- Key: Organizations, OU x N, SCP x N, Account Baseline

### 02-security-baseline
- Add: X resources | Change: X | Destroy: X
- Key: CloudTrail, GuardDuty, SecurityHub, Config

### 03-shared-networking (TGW 활성화 시)
- Add: X resources | Change: X | Destroy: X
- Key: Transit Gateway, RAM Share, Egress VPC

### Total Changes
- Add: X resources | Change: X | Destroy: X

### Execution Order
1. `cd environments/org-foundation/01-organization && terraform apply`
2. `cd environments/org-foundation/02-security-baseline && terraform apply`
3. `cd environments/org-foundation/03-shared-networking && terraform apply`

### Next Steps
- 각 단계를 순서대로 CI/CD 파이프라인에서 apply
- 01 apply 완료 후 02 실행, 02 완료 후 03 실행
```

## Security Notes
- 민감한 출력값은 마스킹하여 표시
- 계정 ID는 로그에서 마스킹
- plan 파일은 임시 저장 후 삭제

## MCP 서버 활용

이 커맨드는 메인 세션에서 실행되므로 MCP 도구를 직접 사용할 수 있습니다.

### Terraform MCP
- **Plan 전 보안 스캔**: `RunCheckovScan`으로 plan 전 보안 검사 실행
- **Plan 오류 해결**: `SearchAwsProviderDocs`로 속성 오류, Provider 호환성 문제 해결
  ```
  예: "Unsupported argument" → SearchAwsProviderDocs로 올바른 속성명 조회
  예: Provider 버전 문제 → 해당 버전 지원 속성 확인
  ```

### AWS Documentation MCP
- **AWS API 오류 해결**: `search_documentation`으로 권한 부족, 리전 미지원 등 오류 원인 조사
- **서비스 할당량 확인**: `read_documentation`으로 할당량 초과 시 해결 방법 조회
  ```
  예: "Access Denied" → IAM 권한 문서 조회
  예: "LimitExceeded" → 서비스 할당량 및 증가 요청 방법 조회
  ```

## Error Handling

### Plan 실패 시
1. 오류 메시지 분석
2. 일반적인 오류 패턴 자동 판별:
   - **"Unsupported argument"**: Terraform MCP `SearchAwsProviderDocs`로 올바른 속성 조회 → 수정 제안
   - **"Access Denied"**: IAM 권한 부족 → 필요 권한 목록 안내
   - **"Backend initialization required"**: `terraform init` 재실행 안내
   - **"State lock"**: 기존 lock 정보 표시 → 해제 방법 안내
   - **"Provider version constraint"**: versions.tf의 제약 조건 확인 → 수정 제안
3. 자동 판별 불가 시: 오류 전문 + Terraform MCP/AWS Docs MCP로 해결 방법 조회

### org-foundation 의존성 오류 시
- 01이 미apply 상태에서 02 Plan 시: "01-organization을 먼저 apply한 후 02를 실행하세요" 안내
- SSM Parameter 미존재 오류: 이전 단계 apply 필요함을 안내
- Remote State 접근 오류: backend.hcl 설정 확인 안내
