output "cluster_id" {
  value = aws_eks_cluster.this.id
}

output "sg_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}