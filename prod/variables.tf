variable "env" {
  type = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = null  # null = ignored, CI/CD won't set this
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "node_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "enable_nat" {
  type    = bool
  default = true
}

variable "admin_users" {
  description = "List of IAM usernames for admin access"
  type        = list(string)
  default     = []
}

variable "editor_users" {
  description = "List of IAM usernames for editor access"
  type        = list(string)
  default     = []
}

variable "viewer_users" {
  description = "List of IAM usernames for viewer access"
  type        = list(string)
  default     = []
}