############################################
# CloudWatch Logs + Metric Filter + Alarm
############################################

# 1) Log group (CloudWatch Logs)
resource "aws_cloudwatch_log_group" "lab1b_app" {
  name              = "/lab1b/app"
  retention_in_days = 14
}

# 2) Metric Filter (Logs -> Metric)
resource "aws_cloudwatch_log_metric_filter" "lab1b_db_failures" {
  name           = "lab1b-db-failures"
  log_group_name = aws_cloudwatch_log_group.lab1b_app.name
  pattern        = "DB_CONNECTION_FAILURE"

  metric_transformation {
    name      = "DBConnectionFailures"
    namespace = "Lab1b/App"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "lab1b_db_failure_alarm" {
  alarm_name        = "lab1b-db-connection-failures"
  alarm_description = "Triggers when DB connection failures exceed threshold"

  namespace           = "Lab1b/App"
  metric_name         = "DBConnectionFailures"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.e5_alerts.arn]
  ok_actions    = [aws_sns_topic.e5_alerts.arn] # optional
}
#______________________________________________________________________________

############################################
# CloudWatch Alarm: ALB 5xx -> SNS
############################################

resource "aws_cloudwatch_metric_alarm" "e5_alb_5xx_alarm01" {
  alarm_name          = "e5-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # Hardcoded defaults (tweak as needed)
  evaluation_periods = 2        # evaluate across 2 periods
  threshold          = 5        # 5xx count threshold (Sum)
  period             = 60       # seconds per period
  statistic          = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.e5_alb01.arn_suffix
  }

  # Update this SNS topic resource name if yours differs
  alarm_actions = [aws_sns_topic.e5_alerts.arn]

  tags = {
    Name = "e5-alb-5xx-alarm01"
  }
}

############################################
# CloudWatch Dashboard (Minimal Skeleton) Loadbalancer
############################################

resource "aws_cloudwatch_dashboard" "e5_dashboard01" {
  dashboard_name = "e5-dashboard01"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",        "LoadBalancer", aws_lb.e5_alb01.arn_suffix],
            [".",                  "HTTPCode_ELB_5XX_Count", ".",         aws_lb.e5_alb01.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "ALB: Requests + 5XX (e5_alb01)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.e5_alb01.arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB: Target Response Time (e5_alb01)"
        }
      }
    ]
  })
}
