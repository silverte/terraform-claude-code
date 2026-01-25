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
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "유효한 CIDR 블록이 필요합니다."
  }
}

variable "availability_zones" {
  description = "사용할 가용 영역 목록"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "최소 2개의 가용 영역이 필요합니다."
  }
}

variable "private_subnet_cidrs" {
  description = "Private 서브넷 CIDR 블록 목록"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public 서브넷 CIDR 블록 목록"
  type        = list(string)
}

#------------------------------------------------------------------------------
# Optional Variables - VPC Settings
#------------------------------------------------------------------------------

variable "enable_dns_hostnames" {
  description = "VPC에서 DNS 호스트 이름 활성화"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "VPC에서 DNS 지원 활성화"
  type        = bool
  default     = true
}

variable "create_igw" {
  description = "Internet Gateway 생성 여부"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Optional Variables - NAT Gateway
#------------------------------------------------------------------------------

variable "enable_nat_gateway" {
  description = "NAT Gateway 생성 여부"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT Gateway 사용 (비용 절감, 비프로덕션용)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Optional Variables - Flow Logs
#------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "VPC Flow Logs 활성화"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Flow Logs 보관 일수"
  type        = number
  default     = 30
}

#------------------------------------------------------------------------------
# Optional Variables - Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "추가 태그"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Public 서브넷 추가 태그 (EKS ALB 등)"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Private 서브넷 추가 태그 (EKS 노드 등)"
  type        = map(string)
  default     = {}
}
