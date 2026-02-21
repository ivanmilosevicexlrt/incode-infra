module vpc {
    source             = "./modules/vpc"    
}
module "eks" {
  source             = "./modules/eks"
  cluster_name       = "prod-eks"
  subnet_ids         = ["subnet-123456", "subnet-abcdef"]
  node_desired_size  = 3
  node_min_size      = 3
  node_max_size      = 6
  node_instance_type = "t3.medium"
}