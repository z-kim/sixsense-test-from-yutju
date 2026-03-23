terraform {
  backend "s3" {
    bucket         = "sixsense-tfstate-storage-team-2026" # S3 버킷 이름
    key            = "project-name/terraform.tfstate" # 저장 경로 및 파일명
    region         = "ap-northeast-2" # 서울 리전
    
    # --- DynamoDB를 이용한 상태 잠금 설정 ---
    dynamodb_table = "terraform-lock-table-team" # DynamoDB 테이블 이름
    encrypt        = true # 상태 파일 암호화 여부
  }
}

