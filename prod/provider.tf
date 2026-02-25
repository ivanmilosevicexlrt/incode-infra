provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
  default_tags {
    tags = {
      env       = var.env
      createdBy = "terraform"
    }
  }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.33.0"
    }
  }

  backend "s3" {
    key            = "plc/terraform.tfstate"
    encrypt        = true
  }
}
