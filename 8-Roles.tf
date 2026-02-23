############################
# EC2 IAM ROLE + PROFILE
############################

resource "aws_iam_role" "lab_ec2_role" {
  name = "lab-ec2-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "lab_ec2_profile" {
  name = "lab-ec2-secrets-profile"
  role = aws_iam_role.lab_ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.lab_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


/* EC2 can fetch the current DB secret to connect to RDS. 
It cannot modify or rotate secrets—those write actions belong to the rotation Lambda. */
resource "aws_iam_role_policy" "ec2_read_db_secret" {
  name = "lab-ec2-read-db-secret"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadOnlyThisSecret"
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = aws_secretsmanager_secret.rds_mysql.arn
    }]
  })
}


# Explanation: CloudWatch logs are the “ship’s black box”—you need them when things explode.
resource "aws_iam_role_policy_attachment" "ec2_cw_attach" {
  role       = aws_iam_role.lab_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

#############################################################
# Rotation Lambda IAM Role (best practice: managed + scoped)
#############################################################

resource "aws_iam_role" "mysql_rotation_lambda_role" {
  name = "lab-mysql-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Basic logging for Lambda → CloudWatch Logs
resource "aws_iam_role_policy_attachment" "rotation_lambda_basic_logs" {
  role       = aws_iam_role.mysql_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# If your rotation Lambda runs in a VPC (yours does, since you made a SG), it needs ENI permissions
resource "aws_iam_role_policy_attachment" "rotation_lambda_vpc_access" {
  role       = aws_iam_role.mysql_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Secret-scoped rotation permissions
resource "aws_iam_role_policy" "mysql_rotation_lambda_secret_policy" {
  name = "lab-mysql-rotation-lambda-secret-policy"
  role = aws_iam_role.mysql_rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RotateThisSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = aws_secretsmanager_secret.rds_mysql.arn
      },
      {
        Sid      = "GetRandomPassword"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetRandomPassword"]
        Resource = "*"
      }
    ]
  })
}