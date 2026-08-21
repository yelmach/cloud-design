# ==============================================================================
# Application Load Balancer (ALB) & Routing Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. ALB Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Controls inbound traffic to Application Load Balancer"
  vpc_id      = var.vpc_id

  # Allow HTTP traffic into ALB from VPC Link / API Gateway
  ingress {
    description = "Allow HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow outbound traffic to backend containers/EC2
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# 2. Application Load Balancer (Internal)
# ------------------------------------------------------------------------------
resource "aws_lb" "main_alb" {
  name               = "${var.project_name}-alb"
  internal           = true # Keeps ALB private; accessible via API Gateway VPC Link
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.private_subnet_ids

  tags = {
    Name      = "${var.project_name}-alb"
  }
}

# ------------------------------------------------------------------------------
# 3. ALB Target Group (Contract for Teammate's ECS Tasks)
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name}-tg"
  port        = 8080 # Port your backend application container listens on
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Health Check configuration to monitor container status
  health_check {
    enabled             = true
    path                = "/health" # Health check endpoint exposed by app
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name      = "${var.project_name}-target-group"
  }
}

# ------------------------------------------------------------------------------
# 4. ALB Listener (Forwards Port 80 to Target Group)
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}