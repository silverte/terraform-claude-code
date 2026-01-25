# Create New Terraform Module

프로젝트 표준에 따라 새로운 Terraform 모듈을 생성합니다.

## Usage
```
/project:tf-module <module-name> [module-type]
```

## Arguments
- **module-name**: 모듈 이름 (예: vpc, eks-cluster, rds-aurora)
- **module-type**: (선택) compute | network | security | storage | database

## Examples
```
/project:tf-module vpc network
/project:tf-module eks-cluster compute
/project:tf-module rds-postgres database
/project:tf-module s3-bucket storage
```

## Execution Steps

### 1. 디렉토리 구조 생성
```bash
MODULE_PATH="modules/$ARGUMENTS"
mkdir -p $MODULE_PATH/{examples/basic,examples/complete,tests}
```

### 2. 기본 파일 생성

#### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

#### variables.tf
표준 변수 포함:
- `project_name` (required)
- `environment` (required)
- `tags` (optional)
- 모듈 타입별 추가 변수

#### outputs.tf
표준 출력 포함:
- `id`
- `arn`
- 모듈 타입별 추가 출력

#### locals.tf
```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "{module-name}"
    },
    var.tags
  )
}
```

#### main.tf
모듈 타입에 따른 기본 리소스 스캐폴딩

### 3. 문서 생성

#### README.md
- 모듈 설명
- 사용 예시
- 입력 변수 테이블
- 출력 값 테이블

#### CHANGELOG.md
```markdown
# Changelog

## [0.1.0] - {today}
### Added
- Initial module creation
```

### 4. 예제 생성

#### examples/basic/main.tf
최소 필수 변수만 사용한 예제

#### examples/complete/main.tf
모든 옵션을 사용한 전체 예제

### 5. 테스트 파일 생성

#### tests/main.tftest.hcl
- 기본 기능 테스트
- 변수 유효성 테스트
- 환경별 설정 테스트

### 6. 검증
```bash
cd $MODULE_PATH
terraform init
terraform validate
terraform fmt
```

## Module Type Templates

### network
- VPC, Subnet, Route Table
- Internet Gateway, NAT Gateway
- Security Groups, NACLs

### compute
- EC2, ASG, Launch Template
- EKS, ECS
- Lambda

### security
- IAM Roles, Policies
- KMS Keys
- Security Groups

### storage
- S3 Buckets
- EFS, EBS

### database
- RDS, Aurora
- DynamoDB
- ElastiCache

## Post-Creation Actions

1. **tf-architect 서브에이전트 호출**
   - 모듈 구조 검토
   - 의존성 분석

2. **코드 검증**
   ```bash
   terraform fmt -recursive
   terraform validate
   tfsec .
   ```

3. **문서 자동 생성**
   ```bash
   terraform-docs markdown table . > README.md
   ```

## Output
```
## Module Created Successfully

### Location
modules/{module-name}/

### Files Created
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── locals.tf
├── README.md
├── CHANGELOG.md
├── examples/
│   ├── basic/main.tf
│   └── complete/main.tf
└── tests/
    └── main.tftest.hcl

### Next Steps
1. Implement resources in main.tf
2. Add module-specific variables
3. Define outputs
4. Update examples
5. Run tests: terraform test
6. Update documentation
```
