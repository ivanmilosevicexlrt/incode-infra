provider "aws" {
  region  = "eu-central-1"
  profile = "terraform"
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
    region         = "eu-central-1"
    bucket         = "terraform-state-imilosevic"
    key            = "${var.env}/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-lock-imilosevic-${var.env}"
  }
}
