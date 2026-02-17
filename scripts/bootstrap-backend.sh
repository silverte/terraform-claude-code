#!/bin/bash
# =============================================================================
# Terraform State Backend Bootstrap Script
# =============================================================================
# S3 버킷과 DynamoDB 테이블을 생성하여 Terraform 원격 State를 준비합니다.
#
# 사용법:
#   ./scripts/bootstrap-backend.sh <project-name> [region] [account-id]
#
# 예시:
#   ./scripts/bootstrap-backend.sh my-web-service
#   ./scripts/bootstrap-backend.sh my-web-service ap-northeast-2 123456789012
# =============================================================================

set -euo pipefail

# --- 인자 파싱 ---
PROJECT_NAME="${1:?프로젝트명을 입력하세요 (예: ./scripts/bootstrap-backend.sh my-web-service)}"
REGION="${2:-ap-northeast-2}"
ACCOUNT_ID="${3:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")}"

if [[ -z "$ACCOUNT_ID" ]]; then
  echo "ERROR: AWS 계정 ID를 확인할 수 없습니다. AWS CLI 설정을 확인하거나 세 번째 인자로 전달하세요."
  exit 1
fi

BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
TABLE_NAME="${PROJECT_NAME}-terraform-lock"

echo "========================================"
echo "Terraform State Backend 부트스트랩"
echo "========================================"
echo "프로젝트:     ${PROJECT_NAME}"
echo "리전:         ${REGION}"
echo "계정 ID:      ${ACCOUNT_ID}"
echo "S3 버킷:      ${BUCKET_NAME}"
echo "DynamoDB:     ${TABLE_NAME}"
echo "========================================"
echo ""

# --- S3 버킷 생성 ---
echo "[1/4] S3 버킷 생성..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "  -> 버킷이 이미 존재합니다. 건너뜁니다."
else
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  echo "  -> 생성 완료"
fi

# --- S3 보안 설정 ---
echo "[2/4] S3 버전관리 및 암호화 설정..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "  -> 버전관리, 암호화, 퍼블릭 차단 설정 완료"

# --- DynamoDB 테이블 생성 ---
echo "[3/4] DynamoDB 락 테이블 생성..."
if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" 2>/dev/null >/dev/null; then
  echo "  -> 테이블이 이미 존재합니다. 건너뜁니다."
else
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  echo "  -> 생성 완료"
fi

# --- 결과 출력 ---
echo ""
echo "[4/4] 부트스트랩 완료!"
echo ""
echo "backend.hcl에 아래 내용을 사용하세요:"
echo "========================================"
echo "bucket         = \"${BUCKET_NAME}\""
echo "key            = \"{environment}/terraform.tfstate\""
echo "region         = \"${REGION}\""
echo "dynamodb_table = \"${TABLE_NAME}\""
echo "encrypt        = true"
echo "========================================"
