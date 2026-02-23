provider "aws" {
  region  = "eu-central-1"
  profile = "terraform-dev"

  default_tags {
    tags = {
      env       = "dev"
      createdBy = "terraform"
    }
  }
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # allows newer 6.x versions, prod is pinned to 6.33.0
    }
  }

  backend "s3" {
    region         = "eu-central-1"
    bucket         = "terraform-state-imilosevic"
    key            = "dev/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-lock-imilosevic-dev"
  }
}
