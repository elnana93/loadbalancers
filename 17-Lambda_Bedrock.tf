data "archive_file" "incident_reporter_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/incident_reporter.py"
  output_path = "${path.module}/incident_reporter.zip"
}

resource "aws_iam_role" "incident_reporter_role" {
  name = "${local.project_name}-incident-reporter-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "LambdaAssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "incident_reporter_basic_logging" {
  role       = aws_iam_role.incident_reporter_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "incident_reporter_logs_query" {
  name = "${local.project_name}-incident-reporter-logs-query01"
  role = aws_iam_role.incident_reporter_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LogsInsightsQuery"
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "incident_reporter" {
  function_name = "${local.project_name}-incident-reporter01"
  role          = aws_iam_role.incident_reporter_role.arn

  filename         = data.archive_file.incident_reporter_zip.output_path
  source_code_hash = data.archive_file.incident_reporter_zip.output_base64sha256

  handler = "incident_reporter.lambda_handler"
  runtime = "python3.12"

  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      WAF_LOG_GROUP        = aws_cloudwatch_log_group.e5_waf_log_group01[0].name
      QUERY_WINDOW_MINUTES = "15"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.incident_reporter_basic_logging,
    aws_iam_role_policy.incident_reporter_logs_query
  ]
}

resource "aws_lambda_permission" "allow_sns_invoke_incident_reporter" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_reporter.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.e5_alerts.arn
}

resource "aws_sns_topic_subscription" "incident_reporter_lambda" {
  topic_arn = aws_sns_topic.e5_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.incident_reporter.arn

  depends_on = [
    aws_lambda_permission.allow_sns_invoke_incident_reporter
  ]
}

output "incident_reporter_lambda_name" {
  value = aws_lambda_function.incident_reporter.function_name
}

output "incident_reporter_lambda_arn" {
  value = aws_lambda_function.incident_reporter.arn
}

output "incident_reporter_role_name" {
  value = aws_iam_role.incident_reporter_role.name
}