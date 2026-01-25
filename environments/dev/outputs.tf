#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private 서브넷 ID 목록"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public 서브넷 ID 목록"
  value       = module.vpc.public_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway Public IP 목록"
  value       = module.vpc.nat_gateway_public_ips
}

output "account_baseline_summary" {
  description = "Account Baseline 적용 요약"
  value       = module.account_baseline.baseline_summary
}
