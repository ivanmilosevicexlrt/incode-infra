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


provider "helm" {
  kubernetes = {
    config_path = "/tmp/kubeconfig-${var.env}-eks"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }    
  }

  backend "s3" {
    key            = "plc/terraform.tfstate"
    encrypt        = true
  }
}
