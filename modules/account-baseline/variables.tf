#------------------------------------------------------------------------------
# Required Variables
#------------------------------------------------------------------------------

variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍에 사용)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "프로젝트 이름은 소문자로 시작하고, 3-21자의 소문자, 숫자, 하이픈만 허용됩니다."
  }
}

variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod", "management", "security", "shared"], var.environment)
    error_message = "환경은 dev, staging, prod, management, security, shared 중 하나여야 합니다."
  }
}

#------------------------------------------------------------------------------
# Optional Variables - CloudTrail
#------------------------------------------------------------------------------

variable "enable_cloudtrail" {
  description = "CloudTrail 활성화 여부"
  type        = bool
  default     = true
}

variable "cloudtrail_bucket_name" {
  description = "CloudTrail 로그를 저장할 S3 버킷 이름"
  type        = string
  default     = null
}

variable "cloudtrail_s3_key_prefix" {
  description = "CloudTrail S3 키 프리픽스"
  type        = string
  default     = "cloudtrail"
}

variable "cloudtrail_kms_key_id" {
  description = "CloudTrail 로그 암호화를 위한 KMS 키 ID"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Optional Variables - GuardDuty
#------------------------------------------------------------------------------

variable "enable_guardduty" {
  description = "GuardDuty 활성화 여부"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Optional Variables - Config
#------------------------------------------------------------------------------

variable "enable_config" {
  description = "AWS Config 활성화 여부"
  type        = bool
  default     = true
}

variable "config_bucket_name" {
  description = "Config 데이터를 저장할 S3 버킷 이름"
  type        = string
  default     = null
}

variable "config_s3_key_prefix" {
  description = "Config S3 키 프리픽스"
  type        = string
  default     = "config"
}

#------------------------------------------------------------------------------
# Optional Variables - Security Hub
#------------------------------------------------------------------------------

variable "enable_security_hub" {
  description = "Security Hub 활성화 여부"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Optional Variables - Terraform Role
#------------------------------------------------------------------------------

variable "create_terraform_role" {
  description = "Terraform 실행 역할 생성 여부"
  type        = bool
  default     = false
}

variable "management_account_id" {
  description = "Management 계정 ID (Terraform 역할 신뢰 정책용)"
  type        = string
  default     = null
}

variable "terraform_external_id" {
  description = "Terraform AssumeRole External ID"
  type        = string
  default     = null
  sensitive   = true
}

#------------------------------------------------------------------------------
# Optional Variables - Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "모든 리소스에 적용할 추가 태그"
  type        = map(string)
  default     = {}
}

variable "owner" {
  description = "리소스 소유자"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "비용 센터"
  type        = string
  default     = "infrastructure"
}
