# AWS Multi-Account Terraform Generator

## 프로젝트 개요
- **요구사항 기반 Terraform 코드 자동 생성 프로젝트**
- YAML 템플릿 기반 대화형 명세서 작성 → Terraform 코드 생성
- Control Tower 미사용 엔터프라이즈 멀티 어카운트 환경
- AWS Organizations + SCP 기반 거버넌스

## 핵심 워크플로우

### 워크로드 배포 (VPC, EC2, ECS, RDS 등)
```
/tf-spec <name>       → 대화형 요구사항 수집 → specs/{name}-spec.yaml
                              ↓
/tf-generate <spec>   → 명세서 기반 코드 생성 → environments/{env}/ + modules/
                              ↓
/tf-review <path>     → 보안/비용/품질 종합 검토
                              ↓
/tf-plan <env>        → terraform plan 실행 및 검증
```

### 조직 기반 설정 (Organizations, OU, SCP, 중앙 보안, TGW)
```
/tf-spec <name>       → "조직 기반 설정" 선택 → specs/{name}-spec.yaml
                              ↓
/tf-generate <spec>   → 3단계 코드 생성:
                         → environments/org-foundation/01-organization/
                         → environments/org-foundation/02-security-baseline/
                         → environments/org-foundation/03-shared-networking/
                              ↓
/tf-review <path>     → 보안/비용/품질 종합 검토
                              ↓
/tf-plan management   → 순서대로 Plan 확인
```

### 사용 예시
```bash
# === 조직 기반 설정 (먼저 실행) ===
/project:tf-spec my-org
# → "조직 기반 설정" 선택 → Organizations, OU, SCP, 보안 서비스 구성
/project:tf-generate specs/my-org-spec.yaml
/project:tf-review environments/org-foundation
/project:tf-plan management

# === 워크로드 배포 (org-foundation 이후) ===
/project:tf-spec my-web-service
# → "워크로드 배포" 선택 → VPC, ECS, RDS 등 구성
/project:tf-generate specs/my-web-service-spec.yaml
/project:tf-review environments/dev
/project:tf-plan dev
```

## 프로젝트 구조

```
.
├── .claude/
│   ├── CLAUDE.md                    # 이 파일 (프로젝트 컨텍스트)
│   ├── settings.json                # 권한/훅 설정
│   ├── agents/                      # 전문 에이전트
│   │   ├── tf-architect.md          # 인프라 설계
│   │   ├── tf-security-reviewer.md  # 보안 검토
│   │   ├── tf-cost-analyzer.md      # 비용 분석
│   │   └── tf-module-developer.md   # 모듈 개발
│   └── commands/                    # 슬래시 커맨드
│       ├── tf-spec.md               # 대화형 요구사항 수집
│       ├── tf-generate.md           # 코드 생성
│       ├── tf-plan.md               # Plan 실행
│       └── tf-review.md             # 종합 리뷰
├── templates/                        # YAML 요구사항 템플릿
│   ├── _base.yaml                   # 공통 (프로젝트, 환경, 태그)
│   ├── organization.yaml            # Organizations, OU, SCP, 중앙 보안, TGW
│   ├── networking.yaml              # VPC, 서브넷, NAT, TGW Attachment
│   ├── compute.yaml                 # EC2, ECS, EKS, Lambda
│   ├── database.yaml                # RDS, DynamoDB, ElastiCache
│   ├── storage.yaml                 # S3, EFS, FSx
│   ├── security.yaml                # IAM, SCP, WAF, GuardDuty
│   └── monitoring.yaml              # CloudWatch, CloudTrail
├── specs/                            # 생성된 요구사항 명세서
├── modules/                          # Terraform 모듈
│   ├── organization/                # 조직 레벨 모듈
│   ├── networking/                  # 네트워크 모듈
│   ├── compute/                     # 컴퓨팅 모듈
│   ├── database/                    # 데이터베이스 모듈
│   ├── storage/                     # 스토리지 모듈
│   ├── security/                    # 보안 모듈
│   └── monitoring/                  # 모니터링 모듈
├── environments/                     # 환경별 배포 설정
│   ├── org-foundation/              # 조직 기반 (3단계)
│   │   ├── 01-organization/         # Organizations, OU, SCP
│   │   ├── 02-security-baseline/    # CloudTrail, GuardDuty, SecurityHub
│   │   └── 03-shared-networking/    # Transit Gateway, Egress VPC
│   ├── dev/                         # Dev 워크로드
│   ├── staging/                     # Staging 워크로드
│   └── prod/                        # Prod 워크로드
└── docs/plans/                       # 설계/구현 문서
```

## 템플릿 규칙

### YAML 명세서 스키마
- `templates/_base.yaml`: 모든 명세서의 공통 필드 (필수)
- `templates/organization.yaml`: org-foundation 전용 (Organizations, OU, SCP, 보안, 네트워크)
- `templates/{category}.yaml`: 워크로드 카테고리별 인프라 설정
- 모든 선택적 기능은 `enabled: true/false` 패턴 사용
- 모든 필드에 기본값 존재 (비전문가 지원)
- `project.type`: `workload` | `org-foundation` 으로 프로젝트 타입 구분

### 명세서 생성 규칙
- `/tf-spec`으로 생성된 파일은 `specs/{name}-spec.yaml`에 저장
- 워크로드: `_base.yaml` + 선택된 카테고리 템플릿의 조합
- org-foundation: `_base.yaml` + `organization.yaml` 조합
- 사용자 확인 후 확정

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
│   ├── Dev OU → Dev Account
│   ├── Staging OU → Staging Account
│   └── Prod OU → Prod Account
└── Sandbox OU
```

## 크로스 계정 접근 패턴
- Management Account에서 AssumeRole로 다른 계정 접근
- 각 계정에 `TerraformExecutionRole` IAM Role 생성
- Trust Policy: Management Account의 Terraform Role만 허용

```hcl
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
| `backend.hcl` | State 백엔드 설정 |
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
  }
}
```

### 모듈 작성 규칙
1. 단일 책임 원칙 준수
2. 모든 변수에 `description`과 `type` 필수
3. sensitive 데이터는 `sensitive = true`
4. `validation` 블록으로 입력 검증
5. `README.md`와 `examples/` 디렉토리 필수

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
- 하드코딩된 시크릿 절대 금지 → Secrets Manager / SSM Parameter Store 사용
- 최소 권한 원칙 적용
- SCP로 위험 작업 차단
- tfsec, checkov 검사 필수 통과
- 모든 S3 버킷 암호화 및 퍼블릭 액세스 차단
- 모든 EBS 볼륨 암호화
- VPC Flow Logs 활성화

### IAM 정책 작성 규칙
```hcl
# 금지: 와일드카드 사용
# "Action": "*", "Resource": "*"

# 권장: 구체적인 권한 명시
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

## State 관리

### 백엔드 설정
- **S3 버킷**: `{project}-terraform-state-{account-id}`
- **DynamoDB 테이블**: `{project}-terraform-lock`
- **환경별 state 파일 분리**
- **state 파일 암호화 필수**

### State 파일 경로
```
s3://{bucket}/
├── org-foundation/
│   ├── organization/terraform.tfstate
│   ├── security-baseline/terraform.tfstate
│   └── shared-networking/terraform.tfstate
├── dev/terraform.tfstate
├── staging/terraform.tfstate
└── prod/terraform.tfstate
```

## 금지 사항 (CRITICAL)

| 항목 | 설명 |
|------|------|
| `terraform apply` 직접 실행 | CI/CD 파이프라인 통해서만 실행 |
| 프로덕션 리소스 수동 변경 | 모든 변경은 코드로 관리 |
| IAM 정책에 `*` 사용 | 예외: 로깅 계정의 특정 케이스만 |
| 퍼블릭 S3 버킷 생성 | Account-level block 적용 |
| Security Group 0.0.0.0/0 | 예외: ALB/NLB 인바운드만 |
| 하드코딩된 시크릿 | Secrets Manager/SSM 사용 |

## 커맨드 가이드

| 커맨드 | 용도 | 사용 시점 |
|--------|------|-----------|
| `/project:tf-spec` | 대화형 요구사항 수집 | 새 인프라 요청 시 |
| `/project:tf-generate` | 명세서 → 코드 생성 | spec 확정 후 |
| `/project:tf-review` | 종합 코드 리뷰 | 코드 생성 후 |
| `/project:tf-plan` | Plan 실행 | 리뷰 통과 후 |

## Subagent 활용 가이드

| Subagent | 용도 | 연동 |
|----------|------|------|
| tf-architect | 인프라 설계 | `/tf-spec`에서 복잡한 설계 판단 시 |
| tf-security-reviewer | 보안 검토 | `/tf-review`에서 보안 검사 시 |
| tf-cost-analyzer | 비용 분석 | `/tf-review`에서 비용 분석 시 |
| tf-module-developer | 모듈 개발 | `/tf-generate`에서 모듈 생성 시 |

## 설치된 스킬 활용

| 스킬 | 용도 | 활용 시점 |
|------|------|-----------|
| terraform-style-guide | HashiCorp 공식 스타일 적용 | 코드 생성/리뷰 시 |
| terraform-module-library | 모듈 구조 패턴 | 모듈 생성 시 |
| terraform-engineer | State/Provider 관리 | 전반적인 코드 생성 시 |

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
| `awslabs.terraform-mcp-server` | Terraform AWS Provider 문서 검색 | 리소스 속성, Data Source 조회 |
| `awslabs.aws-documentation-mcp-server` | AWS 공식 문서 검색 | 서비스 제한, API 레퍼런스, 베스트 프랙티스 |
| `awslabs.well-architected-security-mcp-server` | Well-Architected Security Pillar 평가 | 보안 표준 체크리스트, 보안 상태 분석 |

### 워크플로우별 MCP 활용

| 워크플로우 | MCP 서버 | 활용 시점 |
|------------|----------|-----------|
| `/tf-spec` | Terraform MCP | 리소스 속성 검증 (EKS 버전, RDS 엔진 등) |
| `/tf-spec` | AWS Docs MCP | OU 구조, SCP 가이드라인, 서비스 제한 확인 |
| `/tf-spec` | WA Security MCP | 보안 서비스 권장 구성 참조 |
| `/tf-generate` | Terraform MCP | 모듈 생성 시 리소스 속성 조회 (필수) |
| `/tf-generate` | AWS Docs MCP | 크로스 계정 패턴, 위임 관리자 설정 확인 |
| `/tf-review` | WA Security MCP | Security Pillar 기반 보안 평가 (필수) |
| `/tf-review` | Terraform MCP | deprecated 속성 검증 |
| `/tf-review` | AWS Docs MCP | 서비스별 보안 베스트 프랙티스 참조 |
| `/tf-plan` | Terraform MCP | Plan 오류 시 속성/타입 검증 |
| `/tf-plan` | AWS Docs MCP | AWS API 오류, 할당량 초과 해결 |

### 에이전트별 MCP 활용

| 에이전트 | 주요 MCP | 활용 |
|----------|----------|------|
| tf-architect | AWS Docs + Terraform | 아키텍처 패턴, 서비스 제한, 리소스 의존성 |
| tf-security-reviewer | WA Security + AWS Docs | Security Pillar 평가, 보안 베스트 프랙티스 |
| tf-cost-analyzer | AWS Docs | 최신 가격, 할인 옵션, 프리 티어 |
| tf-module-developer | Terraform (필수) + AWS Docs | 리소스 속성 조회, 서비스 연동 패턴 |

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
