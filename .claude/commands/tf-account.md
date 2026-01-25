# Provision New AWS Account

조직에 새로운 AWS 계정을 프로비저닝하기 위한 Terraform 설정을 생성합니다.

## Usage
```
/project:tf-account <account-name> <ou-path> <account-email>
```

## Arguments
- **account-name**: 계정 이름 (예: workload-dev, data-platform)
- **ou-path**: OU 경로 (예: Workloads/Dev, Infrastructure)
- **account-email**: 계정 루트 이메일

## Examples
```
/project:tf-account workload-dev Workloads/Dev dev-account@company.com
/project:tf-account data-platform Infrastructure/Data data@company.com
/project:tf-account sandbox-team1 Sandbox sandbox1@company.com
```

## Execution Steps

### 1. 계정 정의 파일 생성

#### organization/accounts/{account-name}.tf
```hcl
resource "aws_organizations_account" "{account_name_safe}" {
  name      = "{account-name}"
  email     = "{account-email}"
  parent_id = local.ou_ids["{ou-path}"]
  
  role_name = "OrganizationAccountAccessRole"
  
  iam_user_access_to_billing = "DENY"
  
  tags = {
    Environment = "{environment}"
    ManagedBy   = "terraform"
    Owner       = "{owner}"
  }
  
  lifecycle {
    ignore_changes = [role_name]
  }
}

output "{account_name_safe}_account_id" {
  description = "{account-name} 계정 ID"
  value       = aws_organizations_account.{account_name_safe}.id
}
```

### 2. Account Baseline 설정 생성

#### environments/{account-name}/main.tf
```hcl
module "account_baseline" {
  source = "../../modules/account-baseline"
  
  project_name = var.project_name
  environment  = var.environment
  
  providers = {
    aws = aws.target
  }
}

module "vpc" {
  source = "../../modules/networking/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = !var.is_production
  
  providers = {
    aws = aws.target
  }
}
```

#### environments/{account-name}/providers.tf
```hcl
terraform {
  required_version = ">= 1.5.0"
  
  backend "s3" {
    # backend.hcl에서 설정
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "management"
}

provider "aws" {
  alias  = "target"
  region = var.aws_region
  
  assume_role {
    role_arn     = "arn:aws:iam::${data.aws_organizations_account.this.id}:role/TerraformExecutionRole"
    session_name = "terraform-{account-name}"
  }
}
```

#### environments/{account-name}/backend.hcl
```hcl
bucket         = "{project}-terraform-state-{management-account-id}"
key            = "{account-name}/terraform.tfstate"
region         = "ap-northeast-2"
encrypt        = true
dynamodb_table = "{project}-terraform-lock"
```

### 3. IAM Role 생성 (부트스트랩)

#### _templates/account/bootstrap-role.tf
```hcl
resource "aws_iam_role" "terraform_execution" {
  name = "TerraformExecutionRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.management_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

### 4. SCP 연결 설정

#### organization/scps/{ou-path}.tf
해당 OU에 적용할 SCP 연결

### 5. 변수 파일 생성

#### environments/{account-name}/terraform.tfvars
```hcl
project_name = "{project}"
environment  = "{env}"
aws_region   = "ap-northeast-2"

vpc_cidr             = "10.X.0.0/16"
availability_zones   = ["ap-northeast-2a", "ap-northeast-2c"]
private_subnet_cidrs = ["10.X.1.0/24", "10.X.2.0/24"]
public_subnet_cidrs  = ["10.X.101.0/24", "10.X.102.0/24"]

enable_nat_gateway = true
```

## Security Checklist

tf-security-reviewer 서브에이전트로 검증:

- [ ] Root 계정 MFA 설정 리마인더
- [ ] IAM 패스워드 정책 적용
- [ ] CloudTrail 활성화 및 암호화
- [ ] S3 퍼블릭 액세스 차단
- [ ] EBS 기본 암호화
- [ ] IMDSv2 기본값 설정
- [ ] GuardDuty 멤버 등록
- [ ] Config 규칙 적용

## Post-Creation Steps

1. **Account Factory 실행**
   - Management 계정에서 terraform apply

2. **부트스트랩 역할 생성**
   - OrganizationAccountAccessRole로 접속
   - TerraformExecutionRole 생성

3. **Baseline 적용**
   - 새 계정 디렉토리에서 terraform apply

4. **보안 검증**
   - `/project:tf-review environments/{account-name}`

## Output
```
## Account Configuration Created

### Account Details
- Name: {account-name}
- Email: {account-email}
- OU Path: {ou-path}
- VPC CIDR: 10.X.0.0/16

### Files Created
organization/accounts/{account-name}.tf
environments/{account-name}/
├── main.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── backend.hcl
└── terraform.tfvars

### Deployment Steps
1. Apply account creation:
   cd organization && terraform apply

2. Bootstrap IAM role (manual or via console)

3. Apply baseline:
   cd environments/{account-name}
   terraform init -backend-config=backend.hcl
   terraform apply

### Security Reminders
⚠️ Root 계정 MFA 설정 필수
⚠️ 불필요한 기본 VPC 삭제
⚠️ 보안 연락처 설정
```
