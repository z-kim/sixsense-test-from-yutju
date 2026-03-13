# ============================================================
# Bastion Host (Public 서브넷)
# ============================================================
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = { Name = "Bastion-Host" }
}

# ============================================================
# NAT Instance (Public 서브넷)
# ============================================================
resource "aws_instance" "nat_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  key_name               = var.key_name

  # 핵심: 소스/대상 확인 비활성화 (NAT 동작에 필수)
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash

    # IP 포워딩 영구 활성화
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p

    # iptables MASQUERADE 규칙 적용 (ens5 = Ubuntu on AWS 기본 인터페이스)
    iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

    # 재부팅 후에도 iptables 규칙 유지
    apt-get update -y || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent || true
    netfilter-persistent save || true
  EOF

  tags = { Name = "NAT-Instance" }
}

# ============================================================
# Private 서브넷 EC2 (실제 워크로드 서버)
# ============================================================
resource "aws_instance" "private_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.private_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  # NAT Instance가 완전히 뜬 후 생성
  depends_on = [aws_instance.nat_instance]

  tags = { Name = "Private-Server" }
}
