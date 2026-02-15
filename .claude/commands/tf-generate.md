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
2. 필수 필드 존재 여부 확인:
   - `project.name`, `project.environment`, `project.region`, `project.account_id`
   - `owner.team`, `owner.cost_center`
3. 값 유효성 검증:
   - CIDR 형식
   - 리전 형식
   - 환경 값 (dev, staging, prod)
4. 오류 발견 시 사용자에게 보고하고 수정 안내

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

모듈 매핑 규칙:
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

## Code Generation Rules

1. **CLAUDE.md 코딩 표준 준수**: 파일 구조, 네이밍 규칙, 필수 태그
2. **terraform-style-guide 스킬 적용**: HashiCorp 공식 스타일
3. **terraform-module-library 스킬 참조**: 모듈 구조 패턴
4. **terraform-engineer 스킬 참조**: State 관리, Provider 설정 패턴
5. **보안 가이드라인 적용**: 시크릿 금지, 최소 권한, 암호화 기본 활성화
6. **모든 변수에 description + type + validation**
7. **모든 리소스에 태그 적용**
