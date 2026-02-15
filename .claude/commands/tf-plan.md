# Terraform Plan for Multi-Account

지정된 계정과 환경에 대해 terraform plan을 실행합니다.

## Workflow Position
이 커맨드는 `/tf-spec` → `/tf-generate` → `/tf-review` → **`/tf-plan`** 워크플로우의 마지막 검증 단계입니다.
`/tf-generate`로 코드가 생성된 후 실행하세요.

## Usage
```
/tf-plan <account> [environment]
```

## Arguments
- **account**: management | security | shared | dev | staging | prod
- **environment**: (선택) 특정 환경 워크스페이스

## Examples
```
/tf-plan dev
/tf-plan prod
/tf-plan management
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

## MCP 서버 활용

Plan 실행 과정에서 발생하는 오류 및 경고 해결에 MCP 서버를 활용합니다.

### Terraform MCP (`awslabs.terraform-mcp-server`)
- **Plan 오류 해결**: 리소스 속성 오류, Provider 호환성 문제 등 Plan 실패 시 정확한 속성명/타입 조회
- **활용 시점**: Plan 실패(Step 4) 시 오류 메시지 분석 후 호출
  ```
  예: "Unsupported argument" 오류 시 → 해당 리소스의 올바른 속성명 조회
  예: Provider 버전 호환 문제 시 → 해당 버전에서 지원하는 속성 확인
  ```

### AWS Documentation MCP (`awslabs.aws-documentation-mcp-server`)
- **AWS API 오류 해결**: Plan 중 AWS API 호출 관련 오류 (권한 부족, 리전 미지원 등) 발생 시 원인 조사
- **서비스 제한 확인**: Plan에서 할당량 초과 경고 시 해당 서비스의 할당량 정보 조회
- **활용 시점**: Plan 실패(Step 4) 시 AWS 관련 오류인 경우 호출
  ```
  예: "Access Denied" 오류 시 → 필요한 IAM 권한 문서 조회
  예: "LimitExceeded" 오류 시 → 서비스 할당량 및 증가 요청 방법 조회
  ```

## Error Handling
- 초기화 실패 시: 백엔드 설정 확인 안내
- Plan 실패 시: 오류 원인 분석 및 해결 방안 제시, **Terraform MCP/AWS Docs MCP로 정확한 해결 방법 조회**
- 보안 이슈 발견 시: tf-security-reviewer 서브에이전트 호출 제안
