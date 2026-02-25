
############################################
# Bonus B - WAF Logging (CloudWatch Logs OR S3 OR Firehose)
# One destination per Web ACL, choose via var.waf_log_destination.
############################################

############################################
# WAF logging settings (no vars)
############################################


locals {
  project_name           = "e5"
  enable_waf             = true
  waf_log_destination    = "cloudwatch" # "cloudwatch" | "s3" | "firehose"
  waf_log_retention_days = 14
}

############################################
# Option 1: CloudWatch Logs destination
############################################

resource "aws_cloudwatch_log_group" "e5_waf_log_group01" {
  count = local.waf_log_destination == "cloudwatch" ? 1 : 0

  # AWS requires WAF log destination names to start with aws-waf-logs-
  name              = "aws-waf-logs-${local.project_name}-webacl01"
  retention_in_days = local.waf_log_retention_days

  tags = {
    Name = "${local.project_name}-waf-log-group01"
  }
}

# WAF -> CloudWatch Logs
resource "aws_wafv2_web_acl_logging_configuration" "e5_waf_logging_cloudwatch01" {
  count = local.enable_waf && local.waf_log_destination == "cloudwatch" ? 1 : 0

  # Make sure your Web ACL resource label matches this.
  # If yours is still chewbacca_waf01, change this line back temporarily.
  resource_arn = aws_wafv2_web_acl.e5_waf01[0].arn

  log_destination_configs = [
    aws_cloudwatch_log_group.e5_waf_log_group01[0].arn
  ]

  depends_on = [
    aws_wafv2_web_acl.e5_waf01,
    aws_cloudwatch_log_group.e5_waf_log_group01
  ]
}

############################################
# Option 2: S3 destination (direct)
############################################

resource "aws_s3_bucket" "e5_waf_logs_bucket01" {
  count = local.waf_log_destination == "s3" ? 1 : 0

  # WAF logging destination names should start with aws-waf-logs-
  bucket = "aws-waf-logs-${local.project_name}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.project_name}-waf-logs-bucket01"
  }
}

resource "aws_s3_bucket_public_access_block" "e5_waf_logs_pab01" {
  count = local.waf_log_destination == "s3" ? 1 : 0

  bucket                  = aws_s3_bucket.e5_waf_logs_bucket01[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# WAF -> S3
resource "aws_wafv2_web_acl_logging_configuration" "e5_waf_logging_s3_01" {
  count = local.enable_waf && local.waf_log_destination == "s3" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.e5_waf01[0].arn

  log_destination_configs = [
    aws_s3_bucket.e5_waf_logs_bucket01[0].arn
  ]

  depends_on = [
    aws_wafv2_web_acl.e5_waf01,
    aws_s3_bucket.e5_waf_logs_bucket01,
    aws_s3_bucket_public_access_block.e5_waf_logs_pab01
  ]
}

############################################
# Option 3: Firehose destination
############################################

resource "aws_s3_bucket" "e5_firehose_waf_dest_bucket01" {
  count = local.waf_log_destination == "firehose" ? 1 : 0

  bucket = "${local.project_name}-waf-firehose-dest-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${local.project_name}-waf-firehose-dest-bucket01"
  }
}

resource "aws_iam_role" "e5_firehose_role01" {
  count = local.waf_log_destination == "firehose" ? 1 : 0
  name  = "${local.project_name}-firehose-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "e5_firehose_policy01" {
  count = local.waf_log_destination == "firehose" ? 1 : 0
  name  = "${local.project_name}-firehose-policy01"
  role  = aws_iam_role.e5_firehose_role01[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.e5_firehose_waf_dest_bucket01[0].arn,
          "${aws_s3_bucket.e5_firehose_waf_dest_bucket01[0].arn}/*"
        ]
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "e5_waf_firehose01" {
  count       = local.waf_log_destination == "firehose" ? 1 : 0
  name        = "aws-waf-logs-${local.project_name}-firehose01"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.e5_firehose_role01[0].arn
    bucket_arn = aws_s3_bucket.e5_firehose_waf_dest_bucket01[0].arn
    prefix     = "waf-logs/"
  }
}

# WAF -> Firehose
resource "aws_wafv2_web_acl_logging_configuration" "e5_waf_logging_firehose01" {
  count = local.enable_waf && local.waf_log_destination == "firehose" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.e5_waf01[0].arn

  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.e5_waf_firehose01[0].arn
  ]

  depends_on = [
    aws_wafv2_web_acl.e5_waf01,
    aws_kinesis_firehose_delivery_stream.e5_waf_firehose01
  ]
}

#_______

############################################
# WAFv2 Web ACL (Basic managed rules)
############################################
############################################
# WAFv2 Web ACL (Basic managed rules)
############################################

resource "aws_wafv2_web_acl" "e5_waf01" {
  count = local.enable_waf ? 1 : 0

  name  = "${local.project_name}-waf01"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.project_name}-waf01"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${local.project_name}-waf01"
  }
}

############################################
# Attach WAF Web ACL to ALB
############################################

resource "aws_wafv2_web_acl_association" "e5_waf_assoc01" {
  count = local.enable_waf ? 1 : 0

  resource_arn = aws_lb.e5_alb01.arn
  web_acl_arn  = aws_wafv2_web_acl.e5_waf01[0].arn
}



