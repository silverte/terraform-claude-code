# Terraform Plan for Multi-Account

지정된 계정과 환경에 대해 terraform plan을 실행합니다.

## Workflow Position
이 커맨드는 `/tf-spec` → `/tf-generate` → `/tf-review` → **`/tf-plan`** 워크플로우의 마지막 검증 단계입니다.
`/tf-generate`로 코드가 생성된 후 실행하세요.

## Usage
```
/project:tf-plan <account> [environment]
```

## Arguments
- **account**: management | security | shared | dev | staging | prod
- **environment**: (선택) 특정 환경 워크스페이스

## Examples
```
/project:tf-plan dev
/project:tf-plan prod
/project:tf-plan management
```

## Execution Steps

### 1. 환경 디렉토리 이동
```bash
cd environments/$ARGUMENTS
```

### 2. Terraform 초기화
```bash
terraform init -backend-config=backend.hcl -reconfigure
```

### 3. 워크스페이스 선택 (해당되는 경우)
```bash
terraform workspace select $ENVIRONMENT || terraform workspace new $ENVIRONMENT
```

### 4. Terraform Plan 실행
```bash
terraform plan -var-file=terraform.tfvars -out=tfplan
```

### 5. Plan 요약 출력
변경 사항을 분석하여 다음 정보 제공:
- 추가될 리소스 수
- 변경될 리소스 수
- 삭제될 리소스 수
- 주요 변경 사항 설명

### 6. 보안 스캔 실행
```bash
tfsec . --minimum-severity HIGH
```

### 7. 비용 추정 (Infracost 설치된 경우)
```bash
infracost breakdown --path . --format table
```

## Security Notes
- 민감한 출력값은 마스킹하여 표시
- 계정 ID는 로그에서 마스킹
- plan 파일은 임시 저장 후 삭제

## Output Format
```
## Terraform Plan Summary

### Environment: {account}
### Workspace: {environment}

### Changes
- ➕ Add: X resources
- 🔄 Change: X resources  
- ➖ Destroy: X resources

### Key Changes
1. {resource_type}.{name} - {action} - {reason}
2. ...

### Security Scan Results
- Critical: X
- High: X
- Medium: X

### Estimated Cost Impact
- Current: $XXX/month
- Projected: $XXX/month
- Difference: +$XX/month
```

## Error Handling
- 초기화 실패 시: 백엔드 설정 확인 안내
- Plan 실패 시: 오류 원인 분석 및 해결 방안 제시
- 보안 이슈 발견 시: tf-security-reviewer 서브에이전트 호출 제안
