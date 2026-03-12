


terraform {
  backend "s3" {
    bucket         = "e5statefiles"
    key            = "SSM-S3Endpoints/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "e5statefiles-locks"
    use_lockfile   = true
  }
}

/* 

terraform init -reconfigure

 */