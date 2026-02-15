# Terraform Code Generator - 명세서 기반 코드 생성

YAML 명세서(spec.yaml)를 읽어 Terraform 코드를 자동 생성합니다.

## Usage
```
/project:tf-generate <spec-file>
```

## Arguments
- **spec-file**: 명세서 경로 (예: specs/my-web-service-spec.yaml)

## Execution Steps

### Phase 1: 명세서 파싱 및 검증

1. spec 파일을 읽고 YAML 파싱
2. `project.type` 필드 확인:
   - `org-foundation` → **org-foundation 생성 흐름**으로 분기
   - `workload` (또는 미지정) → **워크로드 생성 흐름**으로 진행
3. 필수 필드 존재 여부 확인:
   - 공통: `project.name`, `project.region`, `project.account_id`
   - 워크로드: `project.environment`, `owner.team`, `owner.cost_center`
   - org-foundation: `project.account_id` (Management Account)
4. 값 유효성 검증:
   - CIDR 형식, 리전 형식, 환경 값, 계정 ID 형식
5. 오류 발견 시 사용자에게 보고하고 수정 안내

---

## 워크로드 생성 흐름 (project.type: "workload")

### Phase 2: 출력 디렉토리 준비

```bash
TARGET_DIR="environments/{project.environment}"
mkdir -p $TARGET_DIR
```

이미 존재하면 사용자에게 덮어쓰기 여부 확인.

### Phase 3: 모듈 확인 및 생성

spec에서 enabled된 각 카테고리에 대해:

1. `modules/` 에 해당 모듈이 있는지 확인
2. 없으면 tf-module-developer 에이전트를 호출하여 모듈 생성
3. 있으면 기존 모듈 재사용

워크로드 모듈 매핑 규칙:
| Spec 카테고리 | 모듈 경로 |
|---|---|
| networking.vpc | modules/networking/vpc |
| networking.transit_gateway | modules/networking/transit-gateway |
| compute.ec2 | modules/compute/ec2 |
| compute.ecs | modules/compute/ecs |
| compute.eks | modules/compute/eks |
| compute.lambda | modules/compute/lambda |
| database.rds | modules/database/rds |
| database.aurora | modules/database/aurora |
| database.dynamodb | modules/database/dynamodb |
| database.elasticache | modules/database/elasticache |
| storage.s3 | modules/storage/s3 |
| storage.efs | modules/storage/efs |
| security.account_baseline | modules/security/account-baseline |
| security.waf | modules/security/waf |
| security.kms | modules/security/kms |
| monitoring.cloudtrail | modules/monitoring/cloudtrail |
| monitoring.config | modules/monitoring/config |

### Phase 4: 환경 파일 생성

아래 파일들을 `environments/{env}/` 에 생성합니다.

#### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

#### providers.tf
spec의 `project.multi_account.enabled` 여부에 따라:

**싱글 어카운트:**
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}
```

**멀티 어카운트:**
```hcl
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/${var.assume_role_name}"
    session_name = "terraform-${var.environment}"
  }
  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "management"
  region = var.aws_region
}

provider "aws" {
  alias  = "security"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/${var.assume_role_name}"
    session_name = "terraform-${var.environment}"
  }
}
```

#### locals.tf
```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner_team
    CostCenter  = var.cost_center
  }
}
```

#### variables.tf
spec의 모든 설정값을 Terraform 변수로 변환.
CLAUDE.md 규칙: description, type, validation 필수.

#### main.tf
enabled된 카테고리별 모듈 호출:
```hcl
module "vpc" {
  source = "../../modules/networking/vpc"
  # spec에서 추출한 값
}
```

#### outputs.tf
각 모듈의 주요 출력 노출.

#### backend.hcl
State 백엔드 설정.

#### terraform.tfvars
spec 값 기반 변수 파일.

### Phase 5: 코드 품질 검증

```bash
cd environments/{env}
terraform fmt -recursive
terraform validate
```

terraform-style-guide 스킬 규칙 적용.

### Phase 6: 요약 출력

```
## 코드 생성 완료

### 프로젝트: {name}
### 타입: 워크로드 배포
### 환경: {env}
### 리전: {region}

### 생성된 파일
| 파일 | 설명 |
|------|------|
| environments/{env}/versions.tf | Terraform/Provider 버전 |
| ... | ... |

### 생성된 모듈
| 모듈 | 경로 |
|------|------|
| VPC | modules/networking/vpc |
| ... | ... |

### 리소스 요약
| 카테고리 | 리소스 |
|----------|--------|
| 네트워크 | VPC, 2 public subnets, 2 private subnets, NAT Gateway |
| ... | ... |

### 다음 단계
1. terraform.tfvars 값 확인
2. /project:tf-review environments/{env} 코드 검토
3. /project:tf-plan {env} Plan 확인
```

---

## org-foundation 생성 흐름 (project.type: "org-foundation")

### Phase 2-org: 출력 디렉토리 준비

org-foundation은 3단계로 분리하여 blast radius 최소화 및 의존성 순서를 보장합니다.

```bash
mkdir -p environments/org-foundation/01-organization
mkdir -p environments/org-foundation/02-security-baseline
mkdir -p environments/org-foundation/03-shared-networking
```

**단계 분리 이유:**
- **01-organization**: Organizations, OU, SCP → 가장 기본, 다른 모든 것의 전제
- **02-security-baseline**: CloudTrail, GuardDuty, SecurityHub, Config → 01에 의존 (계정/OU 필요)
- **03-shared-networking**: Transit Gateway, Egress VPC → 01, 02에 의존 (계정 구조 필요)

각 단계는 독립적인 state를 가지며, 순서대로 apply합니다.

### Phase 3-org: 모듈 확인 및 생성

spec에서 enabled된 각 섹션에 대해 모듈을 확인합니다.

org-foundation 모듈 매핑 규칙:
| Spec 카테고리 | 모듈 경로 | 단계 |
|---|---|---|
| organization | modules/organization/aws-organization | 01 |
| organizational_units | modules/organization/organizational-unit | 01 |
| scps | modules/organization/service-control-policy | 01 |
| accounts (baseline) | modules/organization/account-baseline | 01 |
| delegated_administrators | modules/organization/delegated-admin | 01 |
| ssm_exports | modules/organization/ssm-exporter | 01, 02, 03 |
| centralized_security.cloudtrail | modules/security/organization-cloudtrail | 02 |
| centralized_security.guardduty | modules/security/guardduty-org | 02 |
| centralized_security.security_hub | modules/security/securityhub-org | 02 |
| centralized_security.config | modules/security/config-aggregator | 02 |
| shared_networking.transit_gateway | modules/networking/transit-gateway | 03 |
| shared_networking.ram_share | modules/networking/tgw-ram-share | 03 |
| shared_networking.egress_vpc | modules/networking/vpc | 03 |

없는 모듈은 tf-module-developer 에이전트를 호출하여 생성합니다.

### Phase 4-org: 환경 파일 생성

각 단계별로 아래 파일들을 생성합니다.

#### 01-organization

**providers.tf** (Management Account에서 직접 실행):
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

# 각 계정에 baseline 적용 시 사용
provider "aws" {
  alias  = "security"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/${var.assume_role_name}"
    session_name = "terraform-org-foundation"
  }
}

# 추가 계정 providers (spec의 accounts.existing_accounts 기반)
```

**main.tf** (예시):
```hcl
module "organization" {
  source = "../../../modules/organization/aws-organization"
  # ...
}

module "ou_core" {
  source    = "../../../modules/organization/organizational-unit"
  parent_id = module.organization.roots[0].id
  name      = "Core"
  # ...
}

module "scp_deny_root" {
  source    = "../../../modules/organization/service-control-policy"
  name      = "deny-root"
  # ...
}

module "ssm_exports" {
  source = "../../../modules/organization/ssm-exporter"
  parameters = {
    "/org/organization-id"     = module.organization.id
    "/org/accounts/management" = var.management_account_id
    "/org/accounts/security"   = var.security_account_id
    # ...
  }
}
```

**backend.hcl**:
```hcl
bucket         = "{bucket}"
key            = "org-foundation/organization/terraform.tfstate"
region         = "{region}"
dynamodb_table = "{lock_table}"
encrypt        = true
```

#### 02-security-baseline

**providers.tf** (Management + Security + Log Archive):
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "security"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/${var.assume_role_name}"
    session_name = "terraform-org-foundation"
  }
}

provider "aws" {
  alias  = "log_archive"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.log_archive_account_id}:role/${var.assume_role_name}"
    session_name = "terraform-org-foundation"
  }
}
```

**data.tf** (01 단계 의존성 참조):
```hcl
# 방법 1: Remote State 참조
data "terraform_remote_state" "organization" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "org-foundation/organization/terraform.tfstate"
    region = var.aws_region
  }
}

# 방법 2: SSM Parameter 참조 (01에서 export한 값)
data "aws_ssm_parameter" "organization_id" {
  name = "/org/organization-id"
}
```

**backend.hcl**:
```hcl
bucket         = "{bucket}"
key            = "org-foundation/security-baseline/terraform.tfstate"
region         = "{region}"
dynamodb_table = "{lock_table}"
encrypt        = true
```

#### 03-shared-networking

**providers.tf** (Management + Shared Services):
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "shared_services"
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.shared_services_account_id}:role/${var.assume_role_name}"
    session_name = "terraform-org-foundation"
  }
}
```

**backend.hcl**:
```hcl
bucket         = "{bucket}"
key            = "org-foundation/shared-networking/terraform.tfstate"
region         = "{region}"
dynamodb_table = "{lock_table}"
encrypt        = true
```

### Phase 5-org: 코드 품질 검증

```bash
cd environments/org-foundation/01-organization && terraform fmt -recursive && terraform validate
cd environments/org-foundation/02-security-baseline && terraform fmt -recursive && terraform validate
cd environments/org-foundation/03-shared-networking && terraform fmt -recursive && terraform validate
```

### Phase 6-org: 요약 출력

```
## 코드 생성 완료

### 프로젝트: {name}
### 타입: 조직 기반 설정 (org-foundation)
### 리전: {region}
### Management Account: {management_account_id}

### 생성된 단계
| 단계 | 경로 | 내용 |
|------|------|------|
| 01 | environments/org-foundation/01-organization/ | Organizations, OU, SCP, Account Baseline |
| 02 | environments/org-foundation/02-security-baseline/ | CloudTrail, GuardDuty, SecurityHub, Config |
| 03 | environments/org-foundation/03-shared-networking/ | Transit Gateway, Egress VPC |

### 생성된 모듈
| 모듈 | 경로 |
|------|------|
| AWS Organization | modules/organization/aws-organization |
| Organizational Unit | modules/organization/organizational-unit |
| Service Control Policy | modules/organization/service-control-policy |
| ... | ... |

### 단계별 실행 순서

⚠️ org-foundation은 반드시 순서대로 실행해야 합니다:

1. **01-organization** (먼저 실행)
   ```
   cd environments/org-foundation/01-organization
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   ```

2. **02-security-baseline** (01 완료 후)
   ```
   cd environments/org-foundation/02-security-baseline
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   ```

3. **03-shared-networking** (02 완료 후, TGW 활성화 시)
   ```
   cd environments/org-foundation/03-shared-networking
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   ```

### 다음 단계
1. 각 단계의 terraform.tfvars 값 확인
2. /project:tf-review environments/org-foundation 코드 검토
3. /project:tf-plan management 순서대로 Plan 확인
```

---

## MCP 서버 활용

코드 생성 과정에서 MCP 서버를 활용하여 정확한 Terraform 코드를 생성합니다.

### Terraform MCP (`awslabs.terraform-mcp-server`)
- **리소스 속성 조회**: 모듈 생성 시 Terraform AWS Provider의 최신 리소스/데이터 소스 속성을 조회하여 정확한 코드 생성
- **필수/선택 속성 확인**: 리소스별 required/optional 속성을 확인하여 누락 방지
- **활용 시점**:
  - Phase 3/3-org(모듈 확인 및 생성): tf-module-developer 에이전트가 새 모듈을 만들 때 리소스 속성 참조
  - Phase 4/4-org(환경 파일 생성): Provider 설정, 리소스 블록의 정확한 속성 확인
  ```
  예: VPC 모듈 생성 시 → aws_vpc, aws_subnet 등의 최신 속성 조회
  예: Organizations 모듈 생성 시 → aws_organizations_organization, aws_organizations_policy 속성 확인
  예: GuardDuty org 모듈 시 → aws_guardduty_organization_configuration 속성 확인
  ```

### AWS Documentation MCP (`awslabs.aws-documentation-mcp-server`)
- **서비스 연동 패턴 확인**: 크로스 계정 접근, 위임 관리자 설정, RAM 공유 등 복잡한 패턴의 올바른 구성 확인
- **API 제한/할당량 참조**: 리소스 생성 시 알아야 할 제한 사항 (SCP 최대 크기, OU 중첩 깊이 등)
- **활용 시점**:
  - Phase 3-org(모듈 생성): org-foundation 모듈의 AWS API 호출 패턴 확인
  - Phase 4-org(환경 파일 생성): 단계 간 의존성의 올바른 구현 방법 확인
  ```
  예: Delegated Administrator 설정 시 → 지원 서비스 목록 및 설정 순서 확인
  예: Organization CloudTrail 시 → S3 버킷 정책, KMS 키 정책 요구사항 확인
  ```

## Code Generation Rules

1. **CLAUDE.md 코딩 표준 준수**: 파일 구조, 네이밍 규칙, 필수 태그
2. **terraform-style-guide 스킬 적용**: HashiCorp 공식 스타일
3. **terraform-module-library 스킬 참조**: 모듈 구조 패턴
4. **terraform-engineer 스킬 참조**: State 관리, Provider 설정 패턴
5. **보안 가이드라인 적용**: 시크릿 금지, 최소 권한, 암호화 기본 활성화
6. **모든 변수에 description + type + validation**
7. **모든 리소스에 태그 적용**
8. **org-foundation 단계 간 의존성**: remote state 또는 SSM parameter로 참조
