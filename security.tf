# ============================================================
# Bastion Host 보안 그룹
# ============================================================
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH inbound from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 보안 강화 시 본인 IP로 교체 권장
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

# ============================================================
# NAT Instance 보안 그룹
# ============================================================
resource "aws_security_group" "nat_sg" {
  name        = "nat-instance-sg"
  description = "Allow traffic from private subnet and SSH from bastion"
  vpc_id      = aws_vpc.main.id

  # Private 서브넷 → NAT (HTTP/HTTPS 등 NAT 트래픽)
  ingress {
    description = "All traffic from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  # Bastion → NAT Instance SSH (관리용)
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "nat-instance-sg" }
}

# ============================================================
# Private 서버 보안 그룹
# ============================================================
resource "aws_security_group" "private_sg" {
  name        = "private-server-sg"
  description = "Allow SSH from bastion only"
  vpc_id      = aws_vpc.main.id

  # Bastion → Private 서버 SSH
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-server-sg" }
}
