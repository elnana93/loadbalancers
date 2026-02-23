
############################################
# Bonus B - ALB (Public) -> Target Group (Private EC2) + TLS + WAF + Monitoring
############################################


############################################
# Application Load Balancer
############################################

resource "aws_lb" "e5_alb01" {
  name               = "e5-alb01"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.e5_alb_sg01.id]
  subnets         = [for s in aws_subnet.public_subnet : s.id]
  # optional later:
  # access_logs {
  #   bucket  = aws_s3_bucket.alb_logs.bucket
  #   prefix  = "alb"
  #   enabled = true
  # }

  tags = {
    Name = "e5-alb01"
  }
}

############################################
# Target Group + Attachment
############################################

resource "aws_lb_target_group" "e5_tg01" {
  name     = "e5-tg01"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc["myvpc"].id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "e5-tg01"
  }
}

resource "aws_lb_target_group_attachment" "e5_tg_attach01" {
  target_group_arn = aws_lb_target_group.e5_tg01.arn
  target_id        = aws_instance.lab_ec2_app.id
  port             = 80
}



resource "aws_lb_listener" "e5_http_listener01" {
  load_balancer_arn = aws_lb.e5_alb01.arn
  port              = 80
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

resource "aws_lb_listener" "e5_https_listener01" {
  load_balancer_arn = aws_lb.e5_alb01.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = aws_acm_certificate_validation.e5_site_cert_validation01.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.e5_tg01.arn
  }

  depends_on = [aws_acm_certificate_validation.e5_site_cert_validation01]
}



output "lb_dns_name" {
  value       = aws_lb.e5_alb01.dns_name
  description = "The DNS name of the Load Balancer."
}