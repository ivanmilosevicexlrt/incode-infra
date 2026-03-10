###################################################################
# EKS Access Control Module
###################################################################
# This module creates IAM users, groups and roles for EKS access.
# Each access level has:
#   - 1 IAM group
#   - 1 IAM role (assumed by the group via policy)
#   - N IAM users (added to the group)
#   - 1 EKS access entry + policy association
#
# Access levels:
# ┌──────────────┬──────────────────────────┬──────────────────────────────────┐
# │ Role         │ Policy                   │ Access                           │
# ├──────────────┼──────────────────────────┼──────────────────────────────────┤
# │ eks-admin    │ AmazonEKSAdminPolicy     │ Full admin, no cluster config    │
# │ eks-editor   │ AmazonEKSEditPolicy      │ Read + write workloads           │
# │ eks-viewer   │ AmazonEKSViewPolicy      │ Read only                        │
# └──────────────┴──────────────────────────┴──────────────────────────────────┘
#
# Usage:
#   module "eks_access" {
#     source       = "../modules/eks-access"
#     cluster_name = module.eks.cluster_name
#     account_id   = "485876940116"
#     admin_users  = ["john-admin"]
#     editor_users = ["jane-dev", "bob-dev"]
#     viewer_users = ["alice-viewer"]
#   }
#
# User connects with:
#   aws eks update-kubeconfig --region us-east-1 --name prod-eks --profile eks-viewer
#####################################################################################

locals {
  roles = {
    admin = {
      policy     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
      users      = var.admin_users
    }
    editor = {
      policy     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
      users      = var.editor_users
    }
    viewer = {
      policy     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      users      = var.viewer_users
    }
  }
}

# IAM Groups
resource "aws_iam_group" "eks" {
  for_each = local.roles
  name     = "eks-${each.key}"
}

# IAM Roles
resource "aws_iam_role" "eks" {
  for_each = local.roles
  name     = "eks-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Allow each group to assume its role
resource "aws_iam_group_policy" "assume_role" {
  for_each = local.roles
  name     = "assume-eks-${each.key}"
  group    = aws_iam_group.eks[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.eks[each.key].arn
    }]
  })
}

# IAM Users
resource "aws_iam_user" "admin" {
  for_each = toset(var.admin_users)
  name     = each.value
}

resource "aws_iam_user" "editor" {
  for_each = toset(var.editor_users)
  name     = each.value
}

resource "aws_iam_user" "viewer" {
  for_each = toset(var.viewer_users)
  name     = each.value
}

# Add users to groups
resource "aws_iam_group_membership" "admin" {
  count = length(var.admin_users) > 0 ? 1 : 0
  name  = "eks-admin-membership"
  group = aws_iam_group.eks["admin"].name
  users = var.admin_users
  depends_on = [aws_iam_user.admin]
}

resource "aws_iam_group_membership" "editor" {
  count = length(var.editor_users) > 0 ? 1 : 0
  name  = "eks-editor-membership"
  group = aws_iam_group.eks["editor"].name
  users = var.editor_users
  depends_on = [aws_iam_user.editor]
}

resource "aws_iam_group_membership" "viewer" {
  count = length(var.viewer_users) > 0 ? 1 : 0
  name  = "eks-viewer-membership"
  group = aws_iam_group.eks["viewer"].name
  users = var.viewer_users
  depends_on = [aws_iam_user.viewer]
}

# EKS Access Entries
resource "aws_eks_access_entry" "eks" {
  for_each      = local.roles
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks[each.key].arn
}

# EKS Access Policy Associations
resource "aws_eks_access_policy_association" "eks" {
  for_each      = local.roles
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks[each.key].arn
  policy_arn    = each.value.policy

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks]
}