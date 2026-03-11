############################################
# Lambda for Secrets Manager MySQL Rotation
############################################

data "archive_file" "mysql_rotation_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/mysql_rotation/lambda_function.py"
  output_path = "${path.module}/mysql_rotation.zip"
}

resource "aws_cloudwatch_log_group" "mysql_rotation" {
  name              = "/aws/lambda/lab-mysql-rotation"
  retention_in_days = 14
}

data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_lambda_function" "mysql_rotation" {
  function_name = "lab-mysql-rotation"

  role    = aws_iam_role.mysql_rotation_lambda_role.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.11"

  filename         = data.archive_file.mysql_rotation_zip.output_path
  source_code_hash = data.archive_file.mysql_rotation_zip.output_base64sha256

  timeout     = 120
  memory_size = 256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"
      EXCLUDE_CHARACTERS       = "/@\\\" "
      PASSWORD_LENGTH          = "24"
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet["private_a"].id,
      aws_subnet.private_subnet["private_b"].id
    ]
    security_group_ids = [aws_security_group.rotation_lambda_sg.id]
  }

  depends_on = [aws_cloudwatch_log_group.mysql_rotation]
}

resource "aws_lambda_permission" "allow_secretsmanager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mysql_rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.rds_mysql.arn
}