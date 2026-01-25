# Backend Configuration for Dev Environment
# Usage: terraform init -backend-config=backend.hcl

bucket         = "your-project-terraform-state-MANAGEMENT_ACCOUNT_ID"
key            = "dev/terraform.tfstate"
region         = "ap-northeast-2"
encrypt        = true
dynamodb_table = "your-project-terraform-lock"

# Cross-account access (if state bucket is in management account)
# role_arn       = "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/TerraformStateAccessRole"
