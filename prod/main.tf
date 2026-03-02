locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}


#--VPC------------------------------------------------------
module "vpc" {
  source            = "../modules/vpc"
  name              = "prod"
  vpc_cidr          = "10.1.0.0/16"
  az_count          = 3
  enable_monitoring = true
  enable_nat        = true
}

#--EKS------------------------------------------------------
module "eks" {
  source             = "../modules/eks"
  name               = "prod-eks"
  subnet_ids         = module.vpc.app_subnets
  node_desired_size  = 4
  node_min_size      = 3
  node_max_size      = 6
  node_instance_type = var.node_instance_type
}

resource "null_resource" "kubeconfig" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region us-east-1 --profile ${var.aws_profile} --kubeconfig /tmp/kubeconfig-${module.eks.cluster_name}"
  }
}


module "addons" {
  source = "../modules/eks/addons"

  cluster_name      = module.eks.cluster_name
  karpenter_version = "1.9.0"
  eso_version       = "0.10.0"
  karpenter_role_arn = module.eks.karpenter_role_arn
  depends_on = [null_resource.kubeconfig]
  oidc_provider_arn = module.eks.oidc_provider_arn

}

#--DB------------------------------------------------------
module "database" {
  source            = "../modules/database"
  db_engine         = "rds" 
  environment       = "prod"
  db_username       = local.db_creds.username 
  db_password       = local.db_creds.password 
  subnet_group_name = module.vpc.db_subnet_group
  
  security_group_ids = [module.eks.sg_id]
  depends_on = [ module.eks ] 
}

#--ECR------------------------------------------------------
resource "aws_ecr_repository" "incodedemo_api" {
  name                 = "incodedemo-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.env
    Project     = "incodedemo"
  }
}

resource "aws_ecr_repository_policy" "incodedemo_api" {
  repository = aws_ecr_repository.incodedemo_api.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSPull"
        Effect = "Allow"
        Principal = {
          AWS = module.eks.node_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "incodedemo_api_lifecycle" {
  repository = aws_ecr_repository.incodedemo_api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}


