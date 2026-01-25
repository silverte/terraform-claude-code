#------------------------------------------------------------------------------
# Required Variables
#------------------------------------------------------------------------------

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

#------------------------------------------------------------------------------
# Account IDs
#------------------------------------------------------------------------------

variable "management_account_id" {
  description = "Management 계정 ID"
  type        = string
}

variable "security_account_id" {
  description = "Security 계정 ID"
  type        = string
}

variable "terraform_external_id" {
  description = "Terraform AssumeRole External ID"
  type        = string
  sensitive   = true
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "availability_zones" {
  description = "사용할 가용 영역"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 목록"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 목록"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 생성 여부"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Logging Configuration
#------------------------------------------------------------------------------

variable "cloudtrail_bucket_name" {
  description = "CloudTrail 로그 버킷 이름 (Security 계정)"
  type        = string
}

variable "cloudtrail_kms_key_id" {
  description = "CloudTrail KMS 키 ID"
  type        = string
  default     = null
}

variable "config_bucket_name" {
  description = "Config 데이터 버킷 이름 (Security 계정)"
  type        = string
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "owner" {
  description = "리소스 소유자"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "비용 센터"
  type        = string
  default     = "development"
}

variable "additional_tags" {
  description = "추가 태그"
  type        = map(string)
  default     = {}
}
