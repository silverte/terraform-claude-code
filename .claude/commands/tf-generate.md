# Terraform Code Generator - 명세서 기반 코드 생성

YAML 명세서(spec.yaml)를 읽어 Terraform 코드를 자동 생성합니다.

## Usage
```
/tf-generate <spec-file>
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
| security.guardduty | modules/security/guardduty |
| security.security_hub | modules/security/securityhub |
| security.waf | modules/security/waf |
| security.kms | modules/security/kms |
| monitoring.cloudtrail | modules/monitoring/cloudtrail |
| monitoring.config | modules/monitoring/config |

### Phase 4: 환경 파일 생성

아래 파일들을 `environments/{env}/` 에 생성합니다.

#### versions.tf
```hcl
terraform {
  required_version = ">= 1.7"
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

#### Step 1: 포맷팅 및 문법 검증
```bash
cd environments/{env}
terraform fmt -recursive
terraform validate
```

#### Step 2: 스타일 규칙 검증
생성된 코드에 아래 규칙이 적용되었는지 확인합니다:
- [ ] 리소스 블록 내부 순서: meta-args → args → blocks → tags → lifecycle
- [ ] 복수 리소스 생성에 `for_each` 사용 (`count`는 조건부 생성에만)
- [ ] 변수에 `description`, `type` 존재, 주요 변수에 `validation` 블록
- [ ] 등호(`=`) 정렬 (연속된 인수)
- [ ] `sensitive = true` 적용 (패스워드, 키 등)
- [ ] Provider `default_tags` 블록 사용

위반 항목이 있으면 생성 단계에서 직접 수정합니다.

#### Step 3: 모듈 테스트 파일 확인
생성된 각 모듈에 `tests/main.tftest.hcl` 파일이 존재하는지 확인합니다.
없으면 tf-module-developer가 누락한 것이므로 기본 테스트를 추가합니다:
```bash
# 각 모듈 디렉토리에 tests/ 확인
ls modules/*/tests/main.tftest.hcl 2>/dev/null
```

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
2. /tf-review environments/{env} 코드 검토
3. /tf-plan {env} Plan 확인

> **참고**: `/tf-build`를 사용했다면 리뷰가 이미 포함되어 있으므로
> terraform.tfvars 확인 후 바로 `/tf-plan`을 진행하세요.
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

#### Step 1: 포맷팅 및 문법 검증
```bash
cd environments/org-foundation/01-organization && terraform fmt -recursive && terraform validate
cd environments/org-foundation/02-security-baseline && terraform fmt -recursive && terraform validate
cd environments/org-foundation/03-shared-networking && terraform fmt -recursive && terraform validate
```

#### Step 2: 스타일 규칙 검증 (워크로드 Phase 5 Step 2와 동일 체크리스트 적용)

#### Step 3: 모듈 테스트 파일 확인
org-foundation용 모듈에도 `tests/main.tftest.hcl` 존재 여부 확인:
```bash
ls modules/organization/*/tests/main.tftest.hcl 2>/dev/null
ls modules/security/*/tests/main.tftest.hcl 2>/dev/null
ls modules/networking/*/tests/main.tftest.hcl 2>/dev/null
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
2. /tf-review environments/org-foundation 코드 검토
3. /tf-plan management 순서대로 Plan 확인

> **참고**: `/tf-build`를 사용했다면 리뷰가 이미 포함되어 있으므로
> terraform.tfvars 확인 후 바로 `/tf-plan`을 진행하세요.
```

---

## MCP 서버 활용

이 커맨드는 메인 세션에서 실행되므로 MCP 도구를 직접 사용할 수 있습니다.
**중요**: tf-module-developer 서브에이전트는 MCP 도구에 접근할 수 없습니다. 따라서 모듈 생성을 위임하기 전에 메인 세션에서 MCP로 필요한 정보를 조회하고, 그 결과를 서브에이전트 프롬프트에 포함하세요.

### Terraform MCP - 모듈 생성 전 리소스 속성 조회 (필수)
새 모듈을 생성할 때 반드시 `SearchAwsProviderDocs`로 리소스 속성을 조회합니다:
```
1. 모듈에 포함될 핵심 리소스 목록 파악 (spec 기반)
2. 각 리소스에 대해 SearchAwsProviderDocs 호출
   예: VPC 모듈 → SearchAwsProviderDocs("aws_vpc"), SearchAwsProviderDocs("aws_subnet")
   예: Organizations 모듈 → SearchAwsProviderDocs("aws_organizations_organization")
3. 조회된 속성 정보를 tf-module-developer 서브에이전트 프롬프트에 포함
```

### AWS Documentation MCP - 복잡한 패턴 확인
크로스 계정, 위임 관리자 등 복잡한 패턴은 `search_documentation`으로 확인합니다:
```
예: Delegated Administrator → search_documentation("delegated administrator setup")
예: Organization CloudTrail → search_documentation("organization trail s3 bucket policy")
```

### tf-module-developer 호출 시 프롬프트 구성
```
Task(subagent_type="tf-module-developer", prompt="""
{spec에서 추출한 모듈 요구사항}

## MCP에서 조회한 리소스 속성 (참고)
{SearchAwsProviderDocs 결과 요약}

## 기존 모듈 패턴 참고
{기존 modules/ 디렉토리의 패턴}
""")
```

## Code Generation Rules

1. **CLAUDE.md 코딩 표준 준수**: 파일 구조, 네이밍 규칙, 필수 태그
2. **HCL 스타일 규칙 적용** (tf-module-developer에 내장된 HashiCorp Style Guide 기반 규칙):
   - 블록 내부 순서: meta-args → args → blocks → tags → lifecycle
   - `for_each` 우선 (`count`는 조건부에만)
   - 변수 순서: required → optional → sensitive (각각 알파벳순)
   - 등호 정렬, snake_case 네이밍
3. **모듈 패턴 적용** (tf-module-developer에 내장된 패턴):
   - 단일 책임 모듈, 조건부 리소스, dynamic 블록, 모듈 합성 출력 설계
   - 모든 모듈에 `tests/main.tftest.hcl` 포함 (최소 3개 테스트)
4. **State 관리 패턴**:
   - Partial backend config (`backend.hcl`) 사용
   - 환경별/단계별 state 파일 분리
   - org-foundation 단계 간 의존성: remote state 또는 SSM parameter로 참조
5. **보안 가이드라인 적용**: 시크릿 금지, 최소 권한, 암호화 기본 활성화
6. **모든 변수에 description + type + validation**
7. **모든 리소스에 태그 적용** (provider `default_tags` + 리소스별 `tags`)
8. **Provider 설정**: `default_tags` 블록으로 공통 태그 적용, 멀티 어카운트는 `assume_role` 사용
