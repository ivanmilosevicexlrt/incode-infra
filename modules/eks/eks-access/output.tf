output "role_arns" {
  description = "ARNs of the EKS access roles"
  value = {
    for k, v in aws_iam_role.eks : k => v.arn
  }
}

output "group_names" {
  description = "IAM group names"
  value = {
    for k, v in aws_iam_group.eks : k => v.name
  }
}