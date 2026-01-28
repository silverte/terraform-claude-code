# AWS Multi-Account Terraform Project

## 프로젝트 개요
- Control Tower 미사용 엔터프라이즈 멀티 어카운트 환경
- AWS Organizations + SCP 기반 거버넌스
- GitOps 기반 인프라 관리

## 계정 구조
```
Organization Root
├── Core OU
│   ├── Management Account (MANAGEMENT_ACCOUNT_ID)
│   ├── Security Account (SECURITY_ACCOUNT_ID)
│   └── Log Archive Account (LOG_ARCHIVE_ACCOUNT_ID)
├── Infrastructure OU
│   └── Shared Services Account (SHARED_SERVICES_ACCOUNT_ID)
├── Workloads OU
│   ├── Dev OU
│   │   └── Dev Account (DEV_ACCOUNT_ID)
│   ├── Staging OU
│   │   └── Staging Account (STAGING_ACCOUNT_ID)
│   └── Prod OU
│       └── Prod Account (PROD_ACCOUNT_ID)
└── Sandbox OU
```

## 크로스 계정 접근 패턴
- Management Account에서 AssumeRole로 다른 계정 접근
- 각 계정에 `TerraformExecutionRole` IAM Role 생성
- Trust Policy: Management Account의 Terraform Role만 허용

```hcl
# AssumeRole 패턴 예시
provider "aws" {
  alias  = "target_account"
  region = var.aws_region
  
  assume_role {
    role_arn     = "arn:aws:iam::${var.target_account_id}:role/TerraformExecutionRole"
    session_name = "terraform-${var.environment}"
  }
}
```

## Terraform 코딩 표준

### 파일 구조
| 파일명 | 용도 |
|--------|------|
| `main.tf` | 리소스 정의 |
| `variables.tf` | 입력 변수 |
| `outputs.tf` | 출력 값 |
| `versions.tf` | 프로바이더 및 Terraform 버전 |
| `backend.tf` | State 백엔드 설정 |
| `locals.tf` | 로컬 변수 |
| `data.tf` | 데이터 소스 |

### 네이밍 규칙
- **리소스**: `{project}-{env}-{service}-{resource}`
- **변수**: snake_case
- **출력**: snake_case, 설명적
- **태그**: 필수 태그 항상 포함

### 필수 태그
```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
    CreatedAt   = timestamp()
  }
}
```

### 모듈 작성 규칙
1. 단일 책임 원칙 준수 (하나의 모듈은 하나의 기능만)
2. 모든 변수에 `description`과 `type` 필수
3. sensitive 데이터는 `sensitive = true` 설정
4. `validation` 블록으로 입력 검증
5. `README.md`와 `examples/` 디렉토리 필수
6. 버전 관리를 위한 `CHANGELOG.md` 유지

### 변수 정의 예시
```hcl
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "t3 패밀리 인스턴스만 허용됩니다."
  }
}
```

## 보안 가이드라인

### 필수 사항
- ✅ 하드코딩된 시크릿 절대 금지
- ✅ AWS Secrets Manager 또는 SSM Parameter Store 사용
- ✅ 최소 권한 원칙 적용
- ✅ SCP로 위험 작업 차단
- ✅ tfsec, checkov 검사 필수 통과
- ✅ 모든 S3 버킷 암호화 및 퍼블릭 액세스 차단
- ✅ 모든 EBS 볼륨 암호화
- ✅ VPC Flow Logs 활성화

### IAM 정책 작성 규칙
```hcl
# ❌ 금지: 와일드카드 사용
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}

# ✅ 권장: 구체적인 권한 명시
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

## State 관리

### 백엔드 설정
- **S3 버킷**: `{project}-terraform-state-{account-id}`
- **DynamoDB 테이블**: `{project}-terraform-lock`
- **환경별 state 파일 분리**
- **state 파일 암호화 필수** (SSE-S3 또는 KMS)

### State 파일 경로
```
s3://{bucket}/
├── management/
│   └── terraform.tfstate
├── security/
│   └── terraform.tfstate
├── dev/
│   └── terraform.tfstate
├── staging/
│   └── terraform.tfstate
└── prod/
    └── terraform.tfstate
```

## 금지 사항 (CRITICAL)

| 항목 | 설명 |
|------|------|
| 🚫 `terraform apply` 직접 실행 | CI/CD 파이프라인 통해서만 실행 |
| 🚫 프로덕션 리소스 수동 변경 | 모든 변경은 코드로 관리 |
| 🚫 IAM 정책에 `*` 사용 | 예외: 로깅 계정의 특정 케이스만 |
| 🚫 퍼블릭 S3 버킷 생성 | Account-level block 적용 |
| 🚫 Security Group 0.0.0.0/0 | 예외: ALB/NLB 인바운드만 |
| 🚫 하드코딩된 시크릿 | Secrets Manager/SSM 사용 |

## Extended Thinking 트리거

복잡한 작업 시 다음 키워드 사용:
- `think`: 기본 분석
- `think hard`: 심층 분석
- `think harder`: 복잡한 아키텍처 설계
- `ultrathink`: 대규모 마이그레이션/리팩토링

## Subagent 활용 가이드

| Subagent | 용도 | 트리거 |
|----------|------|--------|
| tf-architect | 인프라 설계 | "설계해줘", "아키텍처" |
| tf-security-reviewer | 보안 검토 | "보안 검토", "취약점" |
| tf-cost-analyzer | 비용 분석 | "비용", "cost" |
| tf-module-developer | 모듈 개발 | "모듈 만들어", "/tf-module" |

## AWS MCP 서버 설정

### 사전 요구사항
```bash
# uv 설치 (Python 패키지 관리자)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 설치 확인
uvx --version
```

### 구성된 MCP 서버

| 서버 | 용도 | 활용 사례 |
|------|------|-----------|
| `awslabs.core-mcp-server` | AWS MCP 서버 조율 | 복잡한 워크플로우 계획 |
| `awslabs.terraform-mcp-server` | Terraform AWS Provider 문서 검색 | WAF, ALB 등 리소스 설정 참조 |
| `awslabs.aws-documentation-mcp-server` | AWS 공식 문서 검색 | 서비스 제한, API 레퍼런스 조회 |

### 활용 예시
```
# WAF 규칙 Terraform 코드 생성 시
"AWS WAF 문서를 검색해서 SQL Injection 방어 규칙을 Terraform으로 작성해줘"

# Organizations SCP 작성 시
"AWS Organizations SCP 베스트 프랙티스를 검색해서 루트 계정 사용 금지 SCP를 만들어줘"

# 새로운 서비스 Terraform 코드 작성 시
"EventBridge Scheduler의 최신 속성을 검색해서 Terraform 모듈을 만들어줘"
```

### MCP 서버 직접 테스트
```bash
# Terraform MCP 서버 테스트
uvx awslabs.terraform-mcp-server@latest

# AWS Documentation MCP 서버 테스트
uvx awslabs.aws-documentation-mcp-server@latest
```

## 참고 문서
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [AWS MCP Servers](https://awslabs.github.io/mcp/)
- [Terraform MCP Server](https://awslabs.github.io/mcp/servers/terraform-mcp-server)
