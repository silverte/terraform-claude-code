---
name: terraform-module-library
description: Build reusable Terraform modules for AWS infrastructure following infrastructure-as-code best practices. Use when creating infrastructure modules, standardizing cloud provisioning, or implementing reusable IaC components.
---

# Terraform Module Library

Production-ready Terraform module patterns for AWS infrastructure.

## Purpose

Create reusable, well-tested Terraform modules for common AWS infrastructure patterns.

## When to Use

- Build reusable infrastructure components
- Standardize AWS resource provisioning
- Implement infrastructure as code best practices
- Establish organizational Terraform standards

## Module Structure

```
modules/
├── organization/       # 조직 레벨 (aws-organization, organizational-unit, service-control-policy)
├── networking/         # 네트워크 (vpc, transit-gateway, tgw-ram-share)
├── compute/           # 컴퓨팅 (ec2, ecs, eks, lambda)
├── database/          # 데이터베이스 (rds, aurora, dynamodb, elasticache)
├── storage/           # 스토리지 (s3, efs)
├── security/          # 보안 (account-baseline, waf, kms, guardduty-org, securityhub-org)
└── monitoring/        # 모니터링 (cloudtrail, config, config-aggregator)
```

## Standard Module Pattern

```
module-name/
├── main.tf          # Main resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider versions
├── README.md        # Documentation
├── examples/        # Usage examples
│   └── complete/
│       ├── main.tf
│       └── variables.tf
└── tests/           # Terraform native test files
    └── main.tftest.hcl
```

## AWS VPC Module Example

**main.tf:**

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

resource "aws_subnet" "private" {
  for_each          = { for idx, cidr in var.private_subnet_cidrs : var.availability_zones[idx] => cidr }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(
    {
      Name = "${var.name}-private-${each.key}"
      Tier = "private"
    },
    var.tags
  )
}

resource "aws_internet_gateway" "main" {
  count  = var.create_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.name}-igw"
    },
    var.tags
  )
}
```

**variables.tf:**

```hcl
variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.cidr_block))
    error_message = "CIDR block must be valid IPv4 CIDR notation."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = []
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

**outputs.tf:**

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of VPC"
  value       = aws_vpc.main.cidr_block
}
```

## Best Practices

1. **Use semantic versioning** for modules
2. **Document all variables** with descriptions
3. **Provide examples** in examples/ directory
4. **Use validation blocks** for input validation
5. **Output important attributes** for module composition
6. **Pin provider versions** in versions.tf
7. **Use locals** for computed values
8. **Implement conditional resources** with for_each (count는 조건부 생성에만)
9. **Test modules** with `.tftest.hcl` (Terraform 1.6+ native test)
10. **Tag all resources** consistently

## Module Composition

```hcl
module "vpc" {
  source = "../../modules/networking/vpc"

  name               = "production"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

  private_subnet_cidrs = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24"
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "rds" {
  source = "../../modules/database/rds"

  identifier     = "production-db"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.large"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Environment = "production"
  }
}
```

## Reference Files

- `references/aws-modules.md` - AWS module patterns

## Testing

```hcl
# tests/main.tftest.hcl

run "vpc_creation" {
  command = plan

  variables {
    name               = "test-vpc"
    cidr_block         = "10.0.0.0/16"
    availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
    private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block should be 10.0.0.0/16"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled"
  }
}

run "subnet_count" {
  command = plan

  variables {
    name               = "test-vpc"
    cidr_block         = "10.0.0.0/16"
    availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
    private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create 2 private subnets"
  }
}

run "no_igw_by_default" {
  command = plan

  variables {
    name               = "test-vpc"
    cidr_block         = "10.0.0.0/16"
    availability_zones = ["ap-northeast-2a"]
  }

  assert {
    condition     = length(aws_internet_gateway.main) == 0
    error_message = "IGW should not be created when create_internet_gateway is false"
  }
}
```

## Related Skills

- `terraform-style-guide` - For HCL formatting conventions
- `terraform-engineer` - For state management and provider configuration
