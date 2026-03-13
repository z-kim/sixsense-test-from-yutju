variable "region" {
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "프라이빗 서브넷 CIDR"
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "가용 영역"
  default     = "ap-northeast-2a"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (서울 리전)"
  default     = "ami-08a4fd517a4872931"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  default     = "t3.micro"
}

variable "key_name" {
  description = "AWS 키페어 이름"
  default     = "sixsense-test"
}
