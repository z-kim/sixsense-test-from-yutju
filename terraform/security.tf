# security.tf
# ============================================================
# Bastion Host SG
# ============================================================
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  vpc_id      = aws_vpc.main.id
  #SSH 접속
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # HTTPS
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
# NAT Instance SG 
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
# Private Service SG (K3s, Kafka, Grafana, Prometheus용 공용)
# ============================================================
resource "aws_security_group" "private_sg" {
  name        = "srv-group"
  vpc_id      = aws_vpc.main.id

  # 1. SSH 관리 (Bastion에서만 가능)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # 2. K3s 내부 통신 (Master-Worker 간 API 통신 등)
  ingress {
    description = "K3s API Server & Internal"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true # 이 SG를 가진 서버끼리 통신 허용
  }

  # 3. Kafka 통신 (기본 9092)
  ingress {
    description = "Kafka Broker"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 4. Grafana 접속 (기본 3000)
  ingress {
    description = "Grafana Web UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all internal traffic within VPC"
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

  tags = { Name = "private-service-sg" }
}

resource "aws_security_group_rule" "allow_prometheus_scraping" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.private_sg.id
  source_security_group_id = aws_security_group.private_sg.id
  description              = "Allow Prometheus to scrape metrics from other nodes"
}  

# ============================================================
# RDS 전용 보안 그룹
# ============================================================
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from private services"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    # Private SG를 가진 서버들만 DB 접속 가능
    security_groups = [aws_security_group.private_sg.id]
  }

  tags = { Name = "rds-sg" }
}

# ============================================================
# ALB SG
# ============================================================
resource "aws_security_group" "alb_sg" {
  name        = "sixsense-alb-sg"
  description = "Allow HTTP traffic to ALB"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sixsense-alb-sg" }
}


# ============================================================
# Prometheus EC2 Service Discovery를 위한 IAM 설정
# ============================================================

# 1. IAM Role: EC2 서비스가 이 역할을 맡을 수 있도록 설정
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

# 2. IAM Policy Attachment: EC2 정보를 읽어올 수 있는 권한 부여
resource "aws_iam_role_policy_attachment" "prometheus_read_only" {
  role       = aws_iam_role.prometheus_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# 3. IAM Instance Profile: 실제 EC2 인스턴스 리소스에 연결할 프로필
resource "aws_iam_instance_profile" "prometheus_profile" {
  name = "sixsense-prometheus-instance-profile"
  role = aws_iam_role.prometheus_role.name
}

# ============================================================
# Prometheus 추가 보안 규칙 (9090 Web UI 접속 허용)
# ============================================================

# VPC 내부 또는 Bastion에서 프로메테우스 웹 대시보드(9090)에 접속할 수 있도록 허용
resource "aws_security_group_rule" "allow_prometheus_web_ui" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  security_group_id = aws_security_group.private_sg.id
  cidr_blocks       = [var.vpc_cidr] # VPC 내부 어디서든 접속 가능
  description       = "Allow access to Prometheus Web UI"
}


# [추가] Bastion Host가 프로메테우스의 메트릭 수집을 허용하도록 설정
resource "aws_security_group_rule" "allow_prometheus_to_bastion" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id      # 문을 열 대상 (Bastion)
  source_security_group_id = aws_security_group.private_sg.id      # 들어올 수 있는 놈 (Prometheus가 속한 SG)
  description              = "Allow Prometheus Server to scrape metrics from Bastion"
}
