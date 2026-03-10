variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "karpenter_version" {
  description = "Karpenter helm chart version"
  type        = string
  default     = "1.9.0"
}

variable "karpenter_role_arn" {
  description = "IAM role ARN for Karpenter Pod Identity"
  type        = string
}
variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "eso_version" {
  description = "External Secrets Operator helm chart version"
  type        = string
  default     = "0.10.0"
}