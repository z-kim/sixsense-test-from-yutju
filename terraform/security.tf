# ============================================================
# 1. DMZ Group (Bastion Host)
# ============================================================
resource "aws_security_group" "bastion_sg" {
  name        = "dmz-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "dmz-group" }
}

# ============================================================
# 2. NAT Instance SG (Private Subnet 인터넷 통로)
# ============================================================
resource "aws_security_group" "nat_sg" {
  name        = "nat-instance-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Traffic from ALL private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
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
# 3. ALB SG (External Load Balancer)
# ============================================================
resource "aws_security_group" "alb_sg" {
  name        = "sixsense-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Prometheus Scraping via ALB"
    from_port   = 30081
    to_port     = 30081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sixsense-alb-sg" }
}

# ============================================================
# 4. Server Farm Group (K3s Nodes, Kafka)
# ============================================================
resource "aws_security_group" "private_sg" {
  name        = "srv-group"
  vpc_id      = aws_vpc.main.id

  # SSH (Bastion 전용)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # K3s 내부 통신
  ingress {
    description = "K3s Internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # K3s API Server
  ingress {
    description = "K3s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  # Kafka (9092)
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ALB 인그레스 통로 (30080)
  ingress {
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # ALB로부터 전달되는 30081 메트릭 트래픽 허용
  ingress {
    description     = "Allow App Metrics from ALB"
    from_port       = 30081
    to_port         = 30081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # [통합] 프로메테우스(mgt-group)의 9100 포트 수집 허용
  ingress {
    description     = "Allow Prometheus Scraping (Node Exporter)"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.mgt_sg.id]
  }

  # [통합] 프로메테우스(mgt-group)의 30081 포트 직접 수집 허용
  ingress {
    description     = "Allow Prometheus Direct Scraping (App Metrics)"
    from_port       = 30081
    to_port         = 30081
    protocol        = "tcp"
    security_groups = [aws_security_group.mgt_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "srv-group" }
}

# ============================================================
# 5. Management Group (Grafana, Prometheus)
# ============================================================
resource "aws_security_group" "mgt_sg" {
  name        = "mgt-group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모니터링 서버 자체로의 3306 접근 허용 (VPC 내부)
  ingress {
    description = "MySQL access to Monitoring Server"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mgt-group" }
}

# ============================================================
# 6. RDS Security Group
# ============================================================
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "MySQL from private services"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.private_sg.id]
  }

  ingress {
    description      = "MySQL from monitoring server"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.mgt_sg.id]
  }
  ingress {
    description     = "MySQL from Bastion Host"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  
  tags = { Name = "rds-sg" }
}

# ============================================================
# 7. Prometheus IAM (Service Discovery용)
# ============================================================
resource "aws_iam_role" "prometheus_role" {
  name = "sixsense-prometheus-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_read_only" {
  role       = aws_iam_role.prometheus_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "sixsense-prometheus-instance-profile"
  role = aws_iam_role.prometheus_role.name
}
