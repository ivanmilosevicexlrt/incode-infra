variable "db_engine" {
  description = "Database engine type: aurora or rds"
  type        = string
  default     = "rds"
  validation {
    condition     = contains(["rds", "aurora"], var.db_engine)
    error_message = "db_engine must be either 'rds' or 'aurora'."
  }
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "environment" {
  description = "Environment type (dev, prod)"
  type        = string
  default     = "dev"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
}

variable "db_password" {
  description = "Master DB password"
  type        = string
  sensitive   = true
}

variable "subnet_group_name" {
  description = "DB subnet group name (private subnets)"
  type        = string
}

# variable "security_group_ids" {
#   description = "Security groups allowed to connect (e.g., EKS SG)"
#   type        = list(string)
# }

variable "db_creds" {
  description = "dbcredentials"
}
