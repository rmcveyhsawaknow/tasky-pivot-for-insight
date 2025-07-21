# ==============================================================================
# APPLICATION LOAD BALANCER MODULE
# ==============================================================================
# Provides cost-effective cloud-native load balancer for EKS applications
# - Internet-facing ALB for public web access
# - Integration with EKS target groups
# - SSL/TLS termination support
# - Health checks and routing rules
# ==============================================================================

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-${var.stack_version}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP access from anywhere
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-${var.stack_version}-alb-sg"
    Component = "load-balancer"
    Type      = "alb-security-group"
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-${var.stack_version}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Enable deletion protection in production
  enable_deletion_protection = var.environment == "production" ? true : false

  # Enable access logs (optional for cost optimization)
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "${var.project_name}-alb"
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-${var.stack_version}-alb"
    Component = "load-balancer"
    Type      = "application-load-balancer"
  })
}

# Target Group for EKS Application
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-${var.environment}-${var.stack_version}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Target type is 'ip' for EKS with Fargate or when using pod IPs
  target_type = "ip"

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Deregistration delay for faster deployments
  deregistration_delay = 30

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-${var.stack_version}-tg"
    Component = "load-balancer"
    Type      = "target-group"
  })
}

# HTTP Listener (redirects to HTTPS if SSL is enabled)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - either forward or redirect to HTTPS
  dynamic "default_action" {
    for_each = var.ssl_certificate_arn != null ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  # Forward to target group if no SSL
  dynamic "default_action" {
    for_each = var.ssl_certificate_arn == null ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }

  tags = merge(var.tags, {
    Component = "load-balancer"
    Type      = "http-listener"
  })
}

# HTTPS Listener (only if SSL certificate is provided)
resource "aws_lb_listener" "https" {
  count = var.ssl_certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.tags, {
    Component = "load-balancer"
    Type      = "https-listener"
  })
}

# Route53 Record for custom domain (optional)
resource "aws_route53_record" "app" {
  count = var.create_dns_record && var.domain_name != null && var.hosted_zone_id != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Security Group Rule to allow ALB to reach EKS nodes
resource "aws_security_group_rule" "alb_to_eks" {
  count = length(var.eks_security_group_ids)

  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = var.eks_security_group_ids[count.index]
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow ALB to reach EKS application"
}
