locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "vpc"
    },
    var.tags
  )

  # NAT Gateway count based on settings
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}
