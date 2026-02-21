variable "name" {
  description = "Prefix for VPC resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use (1–3)"
  type        = number
  default     = 1

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "AZ count must be between 1 and 3."
  }
}

# variable "azs" {
#   description = "List of availability zones"
#   type        = list(string)
# }

variable "enable_monitoring" {
  description = "Whether to create monitoring subnets"
  type        = bool
  default     = false
}

variable "enable_nat" {
  description = "Whether to create NAT gateways"
  type        = bool
  default     = false
}
