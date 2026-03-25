# compute.tf
# ============================================================
# 앤서블용 IAM Role 설정 추가
# ============================================================
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ansible_role" {
  name               = "sixsense-ansible-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ec2_readonly" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ansible_profile" {
  name = "sixsense-ansible-profile"
  role = aws_iam_role.ansible_role.name
}

resource "aws_iam_role_policy_attachment" "prometheus_sd_read" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess" 
}

resource "aws_iam_role_policy" "prometheus_tag_read" {
  name = "sixsense-prometheus-tag-read"
  role = aws_iam_role.ansible_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ============================================================
# Bastion Host (Public 서브넷)
# ============================================================
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ansible_profile.name
  private_ip = var.bastion_private_ip
  disable_api_termination = var.switch

  tags = {
    Name    = "Bastion-Host"
    Role    = "bastion"     # Ansible 그룹: @bastion
    Project = "SixSense"
  }
}

# ============================================================
# NAT Instance (Public 서브넷)
# ============================================================
resource "aws_instance" "nat_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.nat_sg.id]
  key_name               = var.key_name
  source_dest_check = false
  iam_instance_profile   = aws_iam_instance_profile.ansible_profile.name 
  private_ip = var.nat_private_ip
  disable_api_termination = var.switch

  user_data = <<-EOF
    #!/bin/bash
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
    netfilter-persistent save
  EOF

  tags = {
    Name    = "NAT-Instance"
    Role    = "nat"         # Ansible 그룹: @nat
    Project = "SixSense"
  }
}

# ============================================================
# [Private Subnet 1] K3s Cluster
# ============================================================

#k3s에 사용할 토큰
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# K3s Master 노드
resource "aws_instance" "k3s_master" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ansible_profile.name
  private_ip = var.k3s_master_private_ip
  disable_api_termination = var.switch

  depends_on = [aws_instance.nat_instance]

  tags = {
    Name    = "K3s-Master"
    Role    = "master"      # Ansible 그룹: @master
    Project = "SixSense"
    Monitor = "true"
  }
}

# K3s Worker 노드
resource "aws_launch_template" "k3s_worker" {
  name_prefix   = "k3s-worker-"
  image_id      = var.ami_id
  instance_type = "t3.small"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.private_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ansible_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    apt-get update -y
    apt-get install -y curl

    curl -sfL https://get.k3s.io | \
      K3S_URL="https://${aws_instance.k3s_master.private_ip}:6443" \
      K3S_TOKEN="${random_password.k3s_token.result}" \
      INSTALL_K3S_EXEC="agent --node-label node-role.k3s-project.io/worker=true --node-label workload=general" \
      sh -
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "K3s-Worker"
      Role    = "worker"
      Project = "SixSense"
      Monitor = "true"
    }
  }
}

resource "aws_autoscaling_group" "k3s_worker" {
  name                      = "k3s-worker-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 2
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id]
  target_group_arns         = [aws_lb_target_group.k3s_tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.k3s_worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "K3s-Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "SixSense"
    propagate_at_launch = true
  }

  tag {
    key                 = "Monitor"
    value               = "true"
    propagate_at_launch = true
  }

  depends_on = [aws_instance.k3s_master]
}
# ============================================================
# [Private Subnet 2] Infra Services (Kafka, Grafana)
# ============================================================

# Kafka 전용 서버
resource "aws_instance" "kafka_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ansible_profile.name
  private_ip = var.kafka_private_ip
  disable_api_termination = var.switch

  depends_on = [aws_instance.nat_instance]

  tags = {
    Name    = "Kafka-Server"
    Role    = "kafka"       
    Project = "SixSense"
  }
}

# Grafana 모니터링 서버
resource "aws_instance" "grafana_server" {
  ami                    = var.ami_id
  instance_type          = "c7i-flex.large"
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.mgt_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ansible_profile.name
  private_ip = var.grafana_private_ip
  disable_api_termination = var.switch

  depends_on = [aws_instance.nat_instance]

  tags = {
    Name    = "Grafana-Server"
    Role    = "monitoring"  
    Monitor = "true"
    Project = "SixSense"
  }
}

# ============================================================
# Amazon RDS (MySQL)
# ============================================================

resource "aws_db_subnet_group" "rds_sg_group" {
  name       = "sixsense-rds-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]     
  tags       = { 
    Name    = "SixSense-RDS-Subnet-Group"
    Project = "SixSense"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier             = "sixsense-rds"

  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "sixsensedb"
  username               = "admin"
  password               = "password123" 
  db_subnet_group_name   = aws_db_subnet_group.rds_sg_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  deletion_protection    = var.switch
  
  tags = { 
    Name    = "SixSense-RDS"
    Role    = "rds"         # RDS 식별용 태그
    Project = "SixSense"
  }
}

# ============================================================
# 고정 IP(EIP) 연결 (Bastion Host)
# ============================================================

data "aws_eip" "bastion_eip" {
  tags = {
    Name = "sixsense-bastion-eip" # 콘솔에서 입력한 태그 값
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = data.aws_eip.bastion_eip.id
}