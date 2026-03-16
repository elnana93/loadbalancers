terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::676373376093:role/tf-lab1c-role"
    session_name = "terraform-deploy"
  }
}


/* 
provider "aws" {
  region = "us-west-2"

  assume_role {
    role_arn     = "arn:aws:iam::676373376093:role/tf-lab1c-role"
    session_name = "terraform-deploy"
  }
}
 */