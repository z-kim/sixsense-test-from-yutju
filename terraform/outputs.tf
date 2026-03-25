# outputs.tf 
# ============================================================
# 접속 지점 (Public)
# ============================================================
output "bastion_public_ip" {
  description = "Bastion Host 고정 퍼블릭 IP (SSH 진입점)"
  value       = data.aws_eip.bastion_eip.public_ip
}

# ============================================================
# K3s Cluster (Private Subnet 1)
# ============================================================
output "k3s_master_private_ip" {
  description = "K3s Master 노드 프라이빗 IP"
  value       = aws_instance.k3s_master.private_ip
}

# ============================================================
# Infrastructure Services (Private Subnet 2)
# ============================================================
output "kafka_private_ip" {
  description = "Kafka 서버 프라이빗 IP"
  value       = aws_instance.kafka_server.private_ip
}

output "grafana_private_ip" {
  description = "Grafana 모니터링 서버 프라이빗 IP"
  value       = aws_instance.grafana_server.private_ip
}

# ============================================================
# Database (RDS)
# ============================================================
output "rds_endpoint" {
  description = "RDS 접속 엔드포인트"
  value       = aws_db_instance.rds_instance.endpoint
}

# ============================================================
# ALB 접속 도메인 주소
# ============================================================
output "alb_dns_name" {
  description = "웹 서비스 접속용 로드밸런서(ALB) 도메인 주소"
  value       = aws_lb.main_alb.dns_name
}


# ============================================================
# K3S token
# ============================================================
output "k3s_token" {
  description = "K3s join token"
  value       = random_password.k3s_token.result
  sensitive   = true
}