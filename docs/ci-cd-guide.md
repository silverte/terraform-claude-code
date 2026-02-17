# CI/CD 파이프라인 가이드

이 프로젝트에서 생성된 Terraform 코드를 안전하게 배포하기 위한 CI/CD 파이프라인 가이드입니다.

## 원칙

- `terraform apply`는 **절대 로컬에서 실행하지 않습니다**
- 모든 변경은 **PR → 승인 → 자동 배포** 흐름을 따릅니다
- AWS 인증은 **OIDC 기반**으로 시크릿 없이 처리합니다

## GitHub Actions 워크플로우

### 1. PR 생성 시: Plan 자동 실행

```yaml
# .github/workflows/terraform-plan.yml
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'environments/**'
      - 'modules/**'

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7"

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets[format('{0}_ACCOUNT_ID', matrix.environment)] }}:role/GitHubActionsRole
          aws-region: ap-northeast-2

      - name: Terraform Init
        working-directory: environments/${{ matrix.environment }}
        run: terraform init -backend-config=backend.hcl

      - name: Terraform Plan
        working-directory: environments/${{ matrix.environment }}
        run: terraform plan -var-file=terraform.tfvars -no-color -out=tfplan
```

### 2. Main 머지 시: Apply 자동 실행

```yaml
# .github/workflows/terraform-apply.yml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'environments/**'
      - 'modules/**'

jobs:
  apply:
    runs-on: ubuntu-latest
    environment: ${{ matrix.environment }}
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7"

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets[format('{0}_ACCOUNT_ID', matrix.environment)] }}:role/GitHubActionsRole
          aws-region: ap-northeast-2

      - name: Terraform Apply
        working-directory: environments/${{ matrix.environment }}
        run: |
          terraform init -backend-config=backend.hcl
          terraform apply -var-file=terraform.tfvars -auto-approve
```

## OIDC 기반 AWS 인증 설정

GitHub Actions에서 AWS 시크릿 키 없이 인증하는 방법입니다.

### 1. AWS IAM Identity Provider 생성

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

### 2. IAM Role 생성

```hcl
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }]
  })
}
```

> `YOUR_ORG/YOUR_REPO`를 실제 GitHub 리포지토리로 교체하세요.

## 환경 보호 규칙

GitHub Environments에서 환경별 보호 규칙을 설정합니다:

| 환경 | 보호 규칙 |
|------|-----------|
| dev | 자동 배포 (보호 없음) |
| staging | 리뷰어 1명 승인 필요 |
| prod | 리뷰어 2명 승인 + 배포 시간 제한 (업무 시간만) |

## org-foundation 배포 순서

org-foundation은 반드시 순서대로 배포합니다:

```
01-organization → (apply 완료 확인) → 02-security-baseline → (apply 완료 확인) → 03-shared-networking
```

별도의 워크플로우 또는 수동 트리거(`workflow_dispatch`)를 사용하세요.

## 시크릿 설정

GitHub Repository Settings → Secrets에 다음을 추가합니다:

| Secret 이름 | 설명 |
|-------------|------|
| `DEV_ACCOUNT_ID` | Dev 계정 ID |
| `STAGING_ACCOUNT_ID` | Staging 계정 ID |
| `PROD_ACCOUNT_ID` | Production 계정 ID |
