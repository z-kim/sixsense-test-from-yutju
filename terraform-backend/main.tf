# 백엔드 리소스 생성용
resource "aws_s3_bucket" "terraform_state" {
  bucket = "sixsense-tfstate-storage-team-2026" # 전 세계 유일한 이름

  # 실수로 삭제 방지
  lifecycle {
    prevent_destroy = true
  }
}

# 버전 관리 활성화 (과거 상태 복구용)
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB 테이블 (Lock용)
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-lock-table-team"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
