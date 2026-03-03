variable "aws_profile" {
  type = string
  default = null  # null = ignored, CI/CD won't set this
}

variable "env" {
  type    = string
  default = "prod"
}