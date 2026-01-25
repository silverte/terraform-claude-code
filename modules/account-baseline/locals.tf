locals {
  # Naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "account-baseline"
      Owner       = var.owner
      CostCenter  = var.cost_center
    },
    var.tags
  )

  # Environment detection
  is_production = var.environment == "prod"
  is_security   = var.environment == "security"
}
