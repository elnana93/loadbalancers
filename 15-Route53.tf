# Use existing public hosted zone in Route53
data "aws_route53_zone" "e5_zone" {
  name         = "e5cloud.com"
  private_zone = false
}

# Apex/root domain -> ALB (e5cloud.com)
resource "aws_route53_record" "e5_apex_alias01" {
  zone_id = data.aws_route53_zone.e5_zone.zone_id
  name    = "e5cloud.com"
  type    = "A"

  alias {
    name                   = aws_lb.e5_alb01.dns_name
    zone_id                = aws_lb.e5_alb01.zone_id
    evaluate_target_health = true
  }
}

# App subdomain -> ALB (app.e5cloud.com)
resource "aws_route53_record" "e5_app_alias01" {
  zone_id = data.aws_route53_zone.e5_zone.zone_id
  name    = "app"
  type    = "A"

  alias {
    name                   = aws_lb.e5_alb01.dns_name
    zone_id                = aws_lb.e5_alb01.zone_id
    evaluate_target_health = true
  }
}

# One ACM cert for both apex + app
resource "aws_acm_certificate" "e5_site_cert01" {
  domain_name               = "e5cloud.com"
  subject_alternative_names = ["app.e5cloud.com"]
  validation_method         = "DNS"

  tags = {
    Name = "e5-site-cert01"
  }
}

# DNS validation records for all names on the cert
resource "aws_route53_record" "e5_site_cert_validation_records01" {
  for_each = {
    for dvo in aws_acm_certificate.e5_site_cert01.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.e5_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  allow_overwrite = true
}

# Wait until ACM becomes ISSUED
resource "aws_acm_certificate_validation" "e5_site_cert_validation01" {
  certificate_arn = aws_acm_certificate.e5_site_cert01.arn

  validation_record_fqdns = [
    for r in aws_route53_record.e5_site_cert_validation_records01 : r.fqdn
  ]
}


output "e5_site_cert_domain_name" {
  description = "Primary domain on ACM certificate"
  value       = aws_acm_certificate.e5_site_cert01.domain_name
}

output "e5_site_cert_sans" {
  description = "Subject alternative names on ACM certificate"
  value       = aws_acm_certificate.e5_site_cert01.subject_alternative_names
}

output "e5_site_cert_arn" {
  description = "ARN of ACM certificate for e5cloud.com + app.e5cloud.com"
  value       = aws_acm_certificate.e5_site_cert01.arn
}