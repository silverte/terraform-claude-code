#------------------------------------------------------------------------------
# Environment: Dev
# Description: 개발 환경 인프라 설정
#------------------------------------------------------------------------------

# Account Baseline
module "account_baseline" {
  source = "../../modules/account-baseline"

  project_name = var.project_name
  environment  = var.environment

  # CloudTrail - Security 계정으로 로그 전송
  enable_cloudtrail      = true
  cloudtrail_bucket_name = var.cloudtrail_bucket_name
  cloudtrail_kms_key_id  = var.cloudtrail_kms_key_id

  # GuardDuty
  enable_guardduty = true

  # Config - Security 계정으로 데이터 전송
  enable_config      = true
  config_bucket_name = var.config_bucket_name

  # Security Hub
  enable_security_hub = true

  # Tags
  tags       = local.common_tags
  owner      = var.owner
  cost_center = var.cost_center
}

# VPC
module "vpc" {
  source = "../../modules/networking/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = true  # Dev 환경은 단일 NAT로 비용 절감

  enable_flow_logs         = true
  flow_logs_retention_days = 7  # Dev는 짧은 보관 기간

  # EKS를 위한 서브넷 태그 (필요시)
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}
