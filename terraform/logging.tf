# logging.tf
# 1. 로그를 저장할 전용 S3 버킷 생성
resource "aws_s3_bucket" "vpc_flow_logs_storage" {
  bucket = "sixsense-vpc-flow-logs-${random_string.suffix.result}" # 전 세계 유일한 이름 생성, 통합할떄는 새로운 버킷을 만들어야 한다.

  force_destroy = true # terraform destroy 시 buket 삭제함

  tags = {
    Name = "vpc-flow-logs-storage"
  }
}

# 2. 비용 절감을 위한 S3 수명 주기 설정 (90일 후 자동 삭제)
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.vpc_flow_logs_storage.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 90 # 90일이 지난 로그는 자동으로 파기
    }
  }
}

# 3. VPC Flow Logs 활성화 및 S3 연결
resource "aws_flow_log" "main_vpc_flow_log" {
  log_destination      = aws_s3_bucket.vpc_flow_logs_storage.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"   # ACCEPT(허용), REJECT(차단) 트래픽 모두 기록
  vpc_id               = aws_vpc.main.id # 시용자의 VPC ID

  tags = {
    Name = "main-vpc-flow-log"
  }
}

# 버킷 이름 중복 방지를 위한 랜덤 스트링 (이미 있으면 기존 것 활용 가능)
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}
