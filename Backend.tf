



terraform {
  backend "s3" {
    bucket = "e5statefiles"
    key    = "SSM-S3Endpoints/terraform.tfstate"

    region = "us-west-2"

    dynamodb_table = "e5statefiles-locks" # This tells Terraform where to find the lock
    encrypt        = true
  }
} 