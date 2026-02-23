# locals {
#   db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
# }

# Aurora PostgreSQL Serverless v2 (for prod)
resource "aws_rds_cluster" "aurora" {
  count                   = var.db_engine == "aurora" ? 1 : 0
  cluster_identifier      = "incode-db-${var.environment}"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  database_name           = "appdb"
  master_username         = var.db_username
  master_password         = var.db_password
  backup_retention_period = var.backup_retention_period
  storage_encrypted       = true
  #vpc_security_group_ids  = var.security_group_ids
  db_subnet_group_name    = var.subnet_group_name

  serverlessv2_scaling_configuration {
    min_capacity = 1
    max_capacity = 3
  }
  skip_final_snapshot = true
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  count              = var.db_engine == "aurora" ? 1 : 0
  identifier         = "incode-db-${var.environment}-instance"
  cluster_identifier = aws_rds_cluster.aurora[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora[0].engine
  engine_version     = aws_rds_cluster.aurora[0].engine_version
  performance_insights_enabled = true
}

# RDS PostgreSQL (for dev)
resource "aws_db_instance" "postgres" {
  count                        = var.db_engine == "rds" ? 1 : 0
  identifier                   = "incode-db-${var.environment}"
  engine                       = "postgres"
  instance_class               = "db.t3.micro"
  allocated_storage            = 5
  storage_type                 = "gp2"
  multi_az                     = false
  username                     = var.db_username
  password                     = var.db_password
  backup_retention_period      = var.backup_retention_period
  storage_encrypted            = true
  publicly_accessible          = false
   #vpc_security_group_ids       = var.security_group_ids
  db_subnet_group_name         = var.subnet_group_name
  performance_insights_enabled = true
  skip_final_snapshot = true
}

# Read Replica (only in prod, only with aurora engine)
resource "aws_rds_cluster_instance" "aurora_replica" {
  count              = var.db_engine == "aurora" && var.environment == "prod" ? 1 : 0
  identifier         = "incode-db-${var.environment}-replica"
  cluster_identifier = aws_rds_cluster.aurora[0].id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora[0].engine
  engine_version     = aws_rds_cluster.aurora[0].engine_version
  performance_insights_enabled = true
  
}