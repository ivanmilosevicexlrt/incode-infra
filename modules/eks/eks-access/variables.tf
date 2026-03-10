variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

# variable "account_id" {
#   description = "AWS account ID"
#   type        = string
# }

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