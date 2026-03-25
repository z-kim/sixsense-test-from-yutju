# s3.tf

# ============================================================
# 1. 전역 중복 방지를 위한 랜덤 문자열 생성
# ============================================================
resource "random_string" "s3_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ============================================================
# 2. S3 버킷 생성
# ============================================================
resource "aws_s3_bucket" "pdf_storage" {
  bucket = "sixsense-pdf-storage-${random_string.s3_suffix.result}"

  tags = {
    Name    = "sixsense-pdf-storage"
    Project = "SixSense"
  }
}

# ============================================================
# 3. S3 퍼블릭 액세스 완전 차단 (Private)
# ============================================================
resource "aws_s3_bucket_public_access_block" "pdf_storage_block" {
  bucket = aws_s3_bucket.pdf_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# 4. S3 수명 주기 (Lifecycle) - 15일 후 자동 삭제
# ============================================================
resource "aws_s3_bucket_lifecycle_configuration" "pdf_storage_lifecycle" {
  bucket = aws_s3_bucket.pdf_storage.id

  rule {
    id     = "delete-after-15-days"
    status = "Enabled"

    expiration {
      days = 15 # 15일 경과 시 삭제
    }
  }
}

# ============================================================
# 5. IAM User 생성 (앱 서버용)
# ============================================================
resource "aws_iam_user" "app_user" {
  name = "sixsense-app-user"
  path = "/"

  tags = {
    Project = "SixSense"
  }
}

# ============================================================
# 6. IAM Access Key 발급
# ============================================================
resource "aws_iam_access_key" "app_user_key" {
  user = aws_iam_user.app_user.name
}

# ============================================================
# 7. IAM 최소 권한 정책 (Policy) 부여
# ============================================================
resource "aws_iam_user_policy" "app_user_s3_policy" {
  name = "sixsense-s3-access-policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pdf_storage.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.pdf_storage.arn}/*"
        ]
      }
    ]
  })
}