#------------------------------------------------------------------------------
# Service Control Policies (SCPs)
# Description: 조직 전체에 적용되는 권한 가드레일
#------------------------------------------------------------------------------

# SCP: Root 계정 사용 금지
resource "aws_organizations_policy" "deny_root_account" {
  name        = "DenyRootAccount"
  description = "Root 계정 사용을 금지합니다"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyRootAccount"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })
}

# SCP: 특정 리전만 허용
resource "aws_organizations_policy" "allowed_regions" {
  name        = "AllowedRegions"
  description = "허용된 리전에서만 리소스 생성 가능"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyAllOutsideAllowedRegions"
        Effect   = "Deny"
        Action   = ["*"]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
          # 글로벌 서비스 예외
          "ForAnyValue:StringNotLike" = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/OrganizationAccountAccessRole",
              "arn:aws:iam::*:role/TerraformExecutionRole"
            ]
          }
        }
      }
    ]
  })
}

# SCP: CloudTrail 비활성화 금지
resource "aws_organizations_policy" "protect_cloudtrail" {
  name        = "ProtectCloudTrail"
  description = "CloudTrail 삭제 및 비활성화를 금지합니다"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
        Condition = {
          "ForAnyValue:StringNotLike" = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/TerraformExecutionRole"
            ]
          }
        }
      }
    ]
  })
}

# SCP: GuardDuty 비활성화 금지
resource "aws_organizations_policy" "protect_guardduty" {
  name        = "ProtectGuardDuty"
  description = "GuardDuty 삭제 및 비활성화를 금지합니다"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisableOrganizationAdminAccount",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:DisassociateMembers"
        ]
        Resource = "*"
      }
    ]
  })
}

# SCP: S3 퍼블릭 액세스 차단
resource "aws_organizations_policy" "deny_public_s3" {
  name        = "DenyPublicS3"
  description = "S3 버킷의 퍼블릭 액세스를 금지합니다"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          "Bool" = {
            "s3:PublicAccessBlockConfiguration.BlockPublicAcls"        = "false"
            "s3:PublicAccessBlockConfiguration.IgnorePublicAcls"       = "false"
            "s3:PublicAccessBlockConfiguration.BlockPublicPolicy"      = "false"
            "s3:PublicAccessBlockConfiguration.RestrictPublicBuckets"  = "false"
          }
        }
      }
    ]
  })
}

# SCP: 특정 인스턴스 타입만 허용 (비용 통제)
resource "aws_organizations_policy" "allowed_instance_types" {
  name        = "AllowedInstanceTypes"
  description = "승인된 EC2 인스턴스 타입만 허용"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnapprovedInstanceTypes"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "arn:aws:ec2:*:*:instance/*"
        Condition = {
          "ForAnyValue:StringNotLike" = {
            "ec2:InstanceType" = var.allowed_instance_types
          }
        }
      }
    ]
  })
}

#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

variable "allowed_regions" {
  description = "허용된 AWS 리전 목록"
  type        = list(string)
  default     = ["ap-northeast-2", "us-east-1"]  # 서울 + 글로벌 서비스용
}

variable "allowed_instance_types" {
  description = "허용된 EC2 인스턴스 타입 패턴"
  type        = list(string)
  default     = ["t3.*", "t3a.*", "m5.*", "m5a.*", "r5.*", "r5a.*", "c5.*", "c5a.*"]
}
