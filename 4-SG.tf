

resource "aws_security_group" "sg_ec2_lab" {
  name        = "sgroup-ec2-lab"
  description = "Private EC2"
  vpc_id      = aws_vpc.vpc["myvpc"].id

  ingress {
    description     = "Allow HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.e5_alb_sg01.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-ec2-lab"
  }
}

resource "aws_security_group" "sg_rds_lab" {
  name        = "sgroup-rds-lab"
  description = "Allow MySQL from EC2 and Rotation Lambda"
  vpc_id      = aws_vpc.vpc["myvpc"].id

  # EC2 -> RDS
  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2_lab.id]
  }

  # Lambda -> RDS (rotation)
  ingress {
    description     = "MySQL from Rotation Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rotation_lambda_sg.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-rds-lab" }
}

resource "aws_security_group" "rotation_lambda_sg" {
  name        = "sgroup-lambda-rotation"
  description = "Security group for Secrets Manager rotation Lambda"
  vpc_id      = aws_vpc.vpc["myvpc"].id

  # No inbound rules needed (Lambda doesn't accept inbound from the internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-lambda-rotation" }
}

#______________________________________________________________________________
resource "aws_security_group" "sg_vpce_lab" {
  name        = "sgroup-vpce-lab"
  description = "Interface VPC Endpoints SG"
  vpc_id      = aws_vpc.vpc["myvpc"].id

  ingress {
    description     = "HTTPS from EC2"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2_lab.id]
  }

  ingress {
    description     = "HTTPS from rotation Lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.rotation_lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-vpce-lab" }
}




############################################
# Security Group: ALB
############################################

resource "aws_security_group" "e5_alb_sg01" {
  name        = "e5-alb-sg01"
  description = "ALB security group"
  vpc_id      = aws_vpc.vpc["myvpc"].id

  # HTTP from anywhere (optional if using 80 -> 443 redirect)
  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow ALB to reach app targets on port 80
  egress {
    description = "Allow outbound to app targets on port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # tighten later to private subnet CIDRs if you want
  }

  tags = {
    Name = "e5-alb-sg01"
  }
}

