#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 목록"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 목록"
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = var.create_igw ? aws_internet_gateway.this[0].id : null
}

output "nat_gateway_ids" {
  description = "NAT Gateway ID 목록"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "NAT Gateway Public IP 목록"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private Route Table ID 목록"
  value       = aws_route_table.private[*].id
}

output "flow_log_id" {
  description = "VPC Flow Log ID"
  value       = var.enable_flow_logs ? aws_flow_log.this[0].id : null
}

output "flow_log_cloudwatch_log_group" {
  description = "VPC Flow Log CloudWatch Log Group 이름"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
