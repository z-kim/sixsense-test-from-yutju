# ============================================================
# 1. 전역 중복 방지를 위한 랜덤 문자열 생성
# ============================================================
resource "random_string" "s3_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ============================================================
# 2. S3 버킷 생성 (PDF 저장용)
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
# 4. S3 수명 주기 (Lifecycle)
# ============================================================
resource "aws_s3_bucket_lifecycle_configuration" "pdf_storage_lifecycle" {
  bucket = aws_s3_bucket.pdf_storage.id

  rule {
    id     = "transition-to-glacier-and-delete"
    status = "Enabled"

    transition {
      days          = 15
      storage_class = "GLACIER" 
    }

    expiration {
      days = 365 
    }
  }
}

# ============================================================
# 5. IAM 정책
# ============================================================
resource "aws_iam_policy" "app_s3_policy" {
  name        = "sixsense-s3-access-policy"
  description = "Policy for EC2 to access PDF S3 bucket securely"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pdf_storage.arn,
          aws_s3_bucket.backup_storage.arn
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
          "${aws_s3_bucket.pdf_storage.arn}/*",
          "${aws_s3_bucket.backup_storage.arn}/*"
        ]
      }
    ]
  })
}

# ============================================================
# 6. IAM Role에 권한 연결
# ============================================================
resource "aws_iam_role_policy_attachment" "app_s3_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.app_s3_policy.arn
}

# ============================================================
# 7. 소산 백업 전용 S3 버킷 생성
# ============================================================
resource "aws_s3_bucket" "backup_storage" {
  bucket = "sixsense-backup-storage-${random_string.s3_suffix.result}"

  tags = {
    Name    = "sixsense-backup-storage"
    Project = "SixSense"
  }
}

# ============================================================
# 8. 백업 버킷 퍼블릭 액세스 완전 차단 (보안)
# ============================================================
resource "aws_s3_bucket_public_access_block" "backup_storage_block" {
  bucket = aws_s3_bucket.backup_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# 9. 백업 버킷 수명 주기 (Lifecycle) - 2일 후 자동 삭제
# ============================================================
resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.backup_storage.id

  rule {
    id     = "backup-expiration"
    status = "Enabled"

    expiration {
      days = 2
    }
  }
}
