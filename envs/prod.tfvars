env                = "prod"
vpc_cidr           = "10.1.0.0/16"
az_count           = 3
node_instance_type = "t3.medium"
node_desired_size  = 3
node_min_size      = 3
node_max_size      = 6
enable_nat         = true