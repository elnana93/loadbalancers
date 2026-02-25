
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

  access_logs {
    bucket  = aws_s3_bucket.e5_alb_logs_bucket01.bucket
    prefix  = "alb"
    enabled = true
  }

  tags = {
    Name = "e5-alb01"
  }

  depends_on = [
    aws_s3_bucket_policy.e5_alb_logs_policy01,
    aws_s3_bucket_public_access_block.e5_alb_logs_pab01,
    aws_s3_bucket_ownership_controls.e5_alb_logs_owner01
  ]
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

data "aws_caller_identity" "current" {}


##################################################################################
# S3 bucket for ALB access logs (optional, but best practice for production)
##################################################################################


# Explanation: This bucket stores ALB access logs.
resource "aws_s3_bucket" "e5_alb_logs_bucket01" {
  bucket = "e5-alb-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "e5_alb_logs_bucket01"
  }
}

# Explanation: Block public access.
resource "aws_s3_bucket_public_access_block" "e5_alb_logs_pab01" {
  bucket                  = aws_s3_bucket.e5_alb_logs_bucket01.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Ownership controls.
resource "aws_s3_bucket_ownership_controls" "e5_alb_logs_owner01" {
  bucket = aws_s3_bucket.e5_alb_logs_bucket01.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

/* resource "aws_s3_bucket_versioning" "e5_alb_logs_versioning" {
  bucket = aws_s3_bucket.e5_alb_logs_bucket01.id

  versioning_configuration {
    status = "Enabled"
  }
} */

# Explanation: TLS-only + ALB log delivery permissions.
resource "aws_s3_bucket_policy" "e5_alb_logs_policy01" {
  bucket = aws_s3_bucket.e5_alb_logs_bucket01.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.e5_alb_logs_bucket01.arn,
          "${aws_s3_bucket.e5_alb_logs_bucket01.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowELBPutObject"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action = "s3:PutObject"

        # Hardcoded prefix = "alb"
        Resource = "${aws_s3_bucket.e5_alb_logs_bucket01.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}
