# Dev environment (1 AZ, smaller instances, no monitoring)
module "vpc" {
  source            = "../modules/vpc"
  name              = "dev"
  vpc_cidr          = "10.2.0.0/16"
  az_count          = 1
  enable_monitoring = false
  enable_nat        = true
}

# module "eks" {
#   source             = "../modules/eks"
#   name               = "dev-eks"
#   subnet_ids         = module.vpc.app_subnets
#   node_desired_size  = 1
#   node_min_size      = 1
#   node_max_size      = 2
#   node_instance_type = "t3.medium"
# }

module "database" {
  source             = "../modules/database"
  db_engine          = "rds"
  environment        = "dev"
  db_username        = data.aws_ssm_parameter.dbuser.value
  db_password        = data.aws_ssm_parameter.dbpassword.value
  subnet_group_name  = module.vpc.db_subnet_group
  
  #security_group_ids = [module.eks.sg_id]
  #depends_on = [ module.eks ] #debug
}
