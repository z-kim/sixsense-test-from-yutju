# security.tf

# ============================================================
# 1. DMZ Group (Bastion Host)
# ============================================================
resource "aws_security_group" "bastion_sg" {
  name        = "dmz-group"
  vpc_id      = aws_vpc.main.id
  
  # DMZ 존 요구사항 (22, 443)
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
# ALB SG
# ============================================================
resource "aws_security_group" "alb_sg" {
  name        = "sixsense-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id
  
  # 외부 사용자가 ALB로 들어오는 80, 443 포트 유지
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
# 2. Server Farm Group (K3s, Kafka)
# ============================================================
resource "aws_security_group" "private_sg" {
  name        = "srv-group"
  vpc_id      = aws_vpc.main.id

  # 1. SSH 접속 (Bastion에서만)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # 2. K3s 내부 통신 (Master-Worker)
  ingress {
    description = "K3s API Server & Internal"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true 
  }

  ingress {
    description = "K3s node-to-node internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # 3. Kafka (9092), MySQL(3306), Node Exporter(9100)
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ALB에서 들어오는 트래픽 허용 (K3s Ingress용)
  ingress {
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 30443
    to_port         = 30443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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
# 3. Management Group (Grafana, Prometheus)
# ============================================================
resource "aws_security_group" "mgt_sg" {
  name        = "mgt-group"
  vpc_id      = aws_vpc.main.id

  # 22(SSH - Bastion 허용), 3000(Grafana), 9090(Prometheus), 9100(Node Exporter)
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mgt-group" }
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
    # Server Farm(private_sg)에서 RDS로 접근할 수 있게 허용
    security_groups = [aws_security_group.private_sg.id]
  }

  tags = { Name = "rds-sg" }
}

# ============================================================
# Prometheus EC2 Service Discovery를 위한 IAM 설정
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

# ============================================================
# Prometheus 추가 보안 규칙 
# ============================================================

# 1. Prometheus가 Server Farm(private_sg)의 9100 메트릭을 수집하도록 허용
resource "aws_security_group_rule" "allow_prometheus_scraping" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.private_sg.id   # 타겟: Server Farm
  source_security_group_id = aws_security_group.mgt_sg.id       # 출발지: Mgt Group (Prometheus)
  description              = "Allow Prometheus to scrape metrics from Server Farm"
}  

# 2. Prometheus가 Bastion의 9100 메트릭을 수집하도록 허용
resource "aws_security_group_rule" "allow_prometheus_to_bastion" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_sg.id   # 타겟: Bastion
  source_security_group_id = aws_security_group.mgt_sg.id       # 출발지: Mgt Group (Prometheus)
  description              = "Allow Prometheus Server to scrape metrics from Bastion"
}