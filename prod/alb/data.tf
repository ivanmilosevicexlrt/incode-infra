data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket  = "terraform-state-in-imilosevic"
    key     = "prod/terraform.tfstate"
    region  = "us-east-1"
    profile = var.aws_profile
  }
}