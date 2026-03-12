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


  # Delete this block if you want to change it back to the previous one
  assume_role {
    role_arn     = "arn:aws:iam::676373376093:role/tf-lab1c-role"
    session_name = "jenkins-terraform"
  }
}