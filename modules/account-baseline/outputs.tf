#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "cloudtrail_id" {
  description = "CloudTrail ID"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].id : null
}

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
}

output "config_recorder_id" {
  description = "Config Recorder ID"
  value       = var.enable_config ? aws_config_configuration_recorder.this[0].id : null
}

output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = var.enable_security_hub ? aws_securityhub_account.this[0].arn : null
}

output "terraform_execution_role_arn" {
  description = "Terraform Execution Role ARN"
  value       = var.create_terraform_role ? aws_iam_role.terraform_execution[0].arn : null
}

output "terraform_execution_role_name" {
  description = "Terraform Execution Role Name"
  value       = var.create_terraform_role ? aws_iam_role.terraform_execution[0].name : null
}

output "baseline_summary" {
  description = "Account Baseline 적용 요약"
  value = {
    password_policy_applied   = true
    s3_public_access_blocked  = true
    ebs_encryption_enabled    = true
    imdsv2_required           = true
    cloudtrail_enabled        = var.enable_cloudtrail
    guardduty_enabled         = var.enable_guardduty
    config_enabled            = var.enable_config
    security_hub_enabled      = var.enable_security_hub
    terraform_role_created    = var.create_terraform_role
  }
}
