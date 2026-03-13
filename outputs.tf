output "bastion_public_ip" {
  description = "Bastion Host 퍼블릭 IP (SSH 진입점)"
  value       = aws_instance.bastion.public_ip
}

output "nat_instance_private_ip" {
  description = "NAT Instance 프라이빗 IP"
  value       = aws_instance.nat_instance.private_ip
}

output "private_server_private_ip" {
  description = "Private Server 프라이빗 IP (Bastion 통해 접속)"
  value       = aws_instance.private_server.private_ip
}
