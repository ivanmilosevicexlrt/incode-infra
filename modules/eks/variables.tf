variable "name" {
  description = "Name of the EKS cluster"
  type        = string

  validation {
    condition     = length(var.name) > 3 && length(var.name) < 30
    error_message = "Cluster name must be between 4 and 30 characters."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "You must provide at least two subnet IDs for high availability."
  }
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "Desired node size must be at least 1."
  }
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 1
    error_message = "Minimum node size must be at least 1."
  }
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4

  validation {
    condition     = var.node_max_size >= var.node_min_size
    error_message = "Maximum node size must be greater than or equal to minimum node size."
  }
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^([a-z0-9]+)\\.[a-z0-9]+$", var.node_instance_type))
    error_message = "Must be a valid EC2 instance type"
  }
}