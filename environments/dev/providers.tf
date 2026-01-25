#------------------------------------------------------------------------------
# Terraform and Provider Configuration
#------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration is in backend.hcl
  backend "s3" {}
}

# Default provider (target account)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Management account provider (for cross-account operations)
provider "aws" {
  alias  = "management"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.management_account_id}:role/TerraformExecutionRole"
    session_name = "terraform-${var.environment}"
    external_id  = var.terraform_external_id
  }
}

# Security account provider (for centralized logging)
provider "aws" {
  alias  = "security"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.security_account_id}:role/TerraformExecutionRole"
    session_name = "terraform-${var.environment}"
    external_id  = var.terraform_external_id
  }
}
