terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Bloco de Dados para buscar a AMI mais recente do Amazon Linux 2023 ---
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Bloco de Dados para renderizar o script de userdata com a variável da região ---
data "template_file" "userdata" {
  template = file("${path.module}/userdata.sh")
  vars = {
    aws_region = var.aws_region
  }
}

# --- Launch Template ---
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.app_instance_profile.name
  }

  user_data = base64encode(data.template_file.userdata.rendered)

  # Garante que o perfil do IAM seja criado antes do Launch Template
  depends_on = [aws_iam_instance_profile.app_instance_profile]
}

# --- Application Load Balancer ---
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]
}

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "main" {
  name_prefix = "${var.project_name}-asg-"
  
  min_size             = var.asg_min_size
  max_size             = var.asg_max_size
  desired_capacity     = var.asg_desired_capacity
  
  vpc_zone_identifier  = [for s in aws_subnet.private : s.id]
  target_group_arns    = [aws_lb_target_group.main.arn]
  
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}
