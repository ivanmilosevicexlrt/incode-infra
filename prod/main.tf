locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}


# For prod (3 AZs)
module "vpc" {
  source            = "../modules/vpc"
  name              = "prod"
  vpc_cidr          = "10.1.0.0/16"
  az_count          = 3
  enable_monitoring = true
  enable_nat        = true
}

module "eks" {
  source             = "../modules/eks"
  name               = "prod-eks"
  subnet_ids         = module.vpc.app_subnets
  node_desired_size  = 4
  node_min_size      = 3
  node_max_size      = 6
  node_instance_type = "t3.micro"
}

module "database" {
  source            = "../modules/database"
  db_engine         = "rds" 
  environment       = "prod"
  db_username       = local.db_creds.username 
  db_password       = local.db_creds.password 
  subnet_group_name = module.vpc.db_subnet_group
  
  security_group_ids = [module.eks.sg_id]
  depends_on = [ module.eks ] #debug
}

