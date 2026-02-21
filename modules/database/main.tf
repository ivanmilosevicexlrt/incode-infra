# Aurora Serverless v2 (for dev/POC)
resource "aws_rds_cluster" "aurora" {
  count               = var.db_engine == "aurora" ? 1 : 0
  engine              = "aurora-postgresql"
  engine_mode         = "provisioned"
  database_name       = "appdb"
  master_username     = var.db_username
  master_password     = var.db_password
  backup_retention_period = 7
  storage_encrypted   = true
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = var.subnet_group_name

  scaling_configuration {
    min_capacity = 1
    max_capacity = 2
  }
}

# RDS PostgreSQL (for prod)
resource "aws_db_instance" "postgres" {
  count               = var.db_engine == "rds" ? 1 : 0
  engine              = "postgres"
  instance_class      = var.environment == "prod" ? "db.t3.medium" : "db.t3.small"
  allocated_storage   = 20
  multi_az            = var.environment == "prod" ? true : false
  username            = var.db_username
  password            = var.db_password
  backup_retention_period = 7
  storage_encrypted   = true
  publicly_accessible = false
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = var.subnet_group_name
  performance_insights_enabled = true
}

# Optional Read Replica (only in prod)
resource "aws_db_instance" "replica" {
  count               = var.environment == "prod" && var.db_engine == "rds" ? 1 : 0
  engine              = "postgres"
  instance_class      = "db.t3.medium"
  replicate_source_db = aws_db_instance.postgres[0].id
  publicly_accessible = false
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = var.subnet_group_name
}
