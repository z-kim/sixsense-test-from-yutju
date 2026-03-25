# variables.tf
# ============================================================
# [Comment] 인스턴스 보호 스위치 
# ============================================================
variable "switch" {
  description = "EC2 인스턴스 종료 방지 (true: 보호됨 / false: 삭제 가능)"
  type        = bool
  default     = true
}

# ============================================================
# [Comment] 인프라 공통 변수 설정
# ============================================================
variable "region" {
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  default     = "192.168.0.0/16"
}

variable "public_subnet_cidr_1" {
  description = "퍼블릭 서브넷 1 CIDR (Bastion, NAT)"
  default     = "192.168.100.0/24"
}

variable "public_subnet_cidr_2" {
  description = "퍼블릭 서브넷 2 CIDR (ALB 이중화용)"
  default     = "192.168.101.0/24"
}

variable "private_subnet_cidr_1" {
  description = "프라이빗 서브넷 1 CIDR (K3s)"
  default     = "192.168.110.0/24"
}

variable "private_subnet_cidr_2" {
  description = "프라이빗 서브넷 2 CIDR (Kafka, RDS)"
  default     = "192.168.120.0/24"
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
  default     = "t3.small"
}

variable "key_name" {
  description = "AWS 키페어 이름"
  default     = "sixsense-test"
}

# ============================================================
# 고정 Private IP 변수 설정
# ============================================================

variable "bastion_private_ip" {
  description = "Bastion Host 프라이빗 IP"
  default     = "192.168.100.10"
}

variable "nat_private_ip" {
  description = "NAT Instance 프라이빗 IP"
  default     = "192.168.100.20"
}

variable "k3s_master_private_ip" {
  description = "K3s Master 노드 프라이빗 IP"
  default     = "192.168.110.10"
}

/*variable "k3s_worker_private_ip" {
  description = "K3s Worker 노드 프라이빗 IP"
  default     = "10.0.11.20"
}

variable "k3s_worker_2_private_ip" {
  description = "K3s Worker 노드 2 프라이빗 IP"
  default     = "10.0.11.30"
}*/

variable "kafka_private_ip" {
  description = "Kafka 서버 프라이빗 IP"
  default     = "192.168.110.40"
}

variable "grafana_private_ip" {
  description = "Grafana 서버 프라이빗 IP"
  default     = "192.168.120.10"
}

