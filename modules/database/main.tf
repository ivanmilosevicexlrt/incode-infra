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
  vpc_security_group_ids  = var.security_group_ids
  db_subnet_group_name    = var.subnet_group_name
  deletion_protection     = var.environment == "prod" ? true : false

  serverlessv2_scaling_configuration {
    min_capacity = var.environment == "prod" ? 1 : 0.5
    max_capacity = var.environment == "prod" ? 16 : 1
  }

  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = "incode-db-${var.environment}-final"
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

###################################################################
# RDS
###################################################################
resource "aws_db_instance" "postgres" {
  count                        = var.db_engine == "rds" ? 1 : 0
  identifier                   = "incode-db-${var.environment}"
  engine                       = "postgres"
  instance_class               = var.db_instance_class
  allocated_storage            = var.environment == "prod" ? 20 : 5
  storage_type                 = "gp2"
  multi_az                     = var.environment == "prod" ? true : false
  username                     = var.db_username
  password                     = var.db_password
  backup_retention_period      = var.backup_retention_period
  storage_encrypted            = true
  publicly_accessible          = false
  vpc_security_group_ids       = var.security_group_ids
  db_subnet_group_name         = var.subnet_group_name
  deletion_protection          = var.environment == "prod" ? true : false
  performance_insights_enabled = var.environment == "prod" ? true : false
  skip_final_snapshot          = var.environment == "prod" ? false : true
  final_snapshot_identifier    = "incode-db-${var.environment}-final"
  auto_minor_version_upgrade   = var.environment == "prod" ? false : true
  apply_immediately            = var.environment == "prod" ? false : true
}

resource "aws_db_instance" "postgres_replica" {
  count               = var.db_engine == "rds" && var.environment == "prod" ? 1 : 0
  identifier          = "incode-db-${var.environment}-replica"
  replicate_source_db = aws_db_instance.postgres[0].arn
  instance_class      = var.db_instance_class
  publicly_accessible = false
  storage_encrypted   = true

  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = var.security_group_ids

  performance_insights_enabled  = true
  skip_final_snapshot           = false
  final_snapshot_identifier     = "incode-db-${var.environment}-replica-final"
  apply_immediately             = false
  auto_minor_version_upgrade    = false
}