# locals {
#   db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
# }

data "aws_secretsmanager_secret" "db_secret" {
  name = "/${var.environment}/app-1/"
}

data "aws_db_subnet_group" "selected" {
  name = var.subnet_group_name
}


###################################################################
# AURORA
###################################################################
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

#-RDS-PROXY-----------------------------------------------------------


# IAM Role for RDS Proxy to access Secrets Manager
resource "aws_iam_role" "proxy_role" {
  name = "incode-db-proxy-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy granting access to the specific secret
resource "aws_iam_policy" "proxy_secret_policy" {
  name        = "incode-db-proxy-secret-policy-${var.environment}"
  description = "Allow RDS Proxy to read DB credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = data.aws_secretsmanager_secret.db_secret.arn
        
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "proxy_secret_attach" {
  role       = aws_iam_role.proxy_role.name
  policy_arn = aws_iam_policy.proxy_secret_policy.arn
}


resource "aws_db_proxy" "postgres_proxy" {
  name                   = "incode-db-proxy-${var.environment}"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy_role.arn # IAM role allowing Secrets Manager access
  vpc_security_group_ids = var.security_group_ids
  vpc_subnet_ids         = data.aws_db_subnet_group.selected.subnet_ids # Ensure these are in the same VPC

  auth {
    auth_scheme = "SECRETS"
    description = "RDS Proxy Auth"
    iam_auth    = "DISABLED"
    secret_arn  = data.aws_secretsmanager_secret.db_secret.arn
  }
}

# 2. Define the Target Group
resource "aws_db_proxy_default_target_group" "postgres_target_group" {
  db_proxy_name = aws_db_proxy.postgres_proxy.name

  connection_pool_config {
    max_connections_percent      = 100
    connection_borrow_timeout    = 120
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

# 3. Register your RDS Instance to the Proxy
resource "aws_db_proxy_target" "postgres_target" {
  db_instance_identifier = aws_db_instance.postgres[0].identifier
  db_proxy_name          = aws_db_proxy.postgres_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.postgres_target_group.name
}