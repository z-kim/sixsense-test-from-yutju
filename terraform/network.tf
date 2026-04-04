# network.tf
# ============================================================
# VPC 및 인터넷 게이트웨이
# ============================================================
provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "SixSense-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "SixSense-IGW" }
}

# ============================================================
# 서브넷 (Subnets) 
# ============================================================

# Public Subnet A (Bastion, NAT Instance 위치)
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_1
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a" 
  tags = { Name = "public-subnet-a" }
}

# Public Subnet C (ALB 이중화용 - AZ를 b로 변경)
resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_2
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b" 
  tags = { Name = "public-subnet-c" }
}

# Private Subnet 1 (K3s Cluster 위치)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_1
  availability_zone = "${var.region}d"
  tags = { Name = "private-subnet-1" }
}

# Private Subnet 2 (Kafka, Monitoring, RDS 위치)
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_2
  availability_zone = "${var.region}b" 
  tags = { Name = "private-subnet-2" }
}

# ============================================================
# 라우팅 테이블 (Routing Tables)
# ============================================================

# Public RT: IGW 연결
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

# 퍼블릭 서브넷 A, C 모두 라우팅 테이블 연결
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_c" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private RT: 모든 프라이빗 트래픽을 NAT Instance로 전달
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_instance.primary_network_interface_id
  }
  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# ============================================================
# ALB (로드밸런서)
# ============================================================
resource "aws_lb" "main_alb" {
  name               = "sixsense-alb"
  internal           = false 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  tags = { Name = "SixSense-ALB" }
}

resource "aws_lb_target_group" "k3s_tg" {
  name        = "k3s-target-group"
  port        = 30080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200-404"
    interval            = 20
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ============================================================
# ALB 80 포트 리스너 (HTTP로 접속하면 HTTPS로 강제 이동)
# ============================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ============================================================
# ALB 443 포트 리스너 
# ============================================================
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  certificate_arn   = aws_acm_certificate_validation.cert_val.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s_tg.arn
  }
}
