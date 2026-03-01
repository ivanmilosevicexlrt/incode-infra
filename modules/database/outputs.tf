output "db_endpoint" {
  description = "Primary connection endpoint"
  value = var.db_engine == "aurora" ? (
    one(aws_rds_cluster.aurora).endpoint
  ) : (
    one(aws_db_proxy.postgres_proxy).endpoint 
  )
}

output "db_reader_endpoint" {
  description = "Read-only endpoint, null if not available"
  value = var.db_engine == "aurora" ? (
    one(aws_rds_cluster.aurora).reader_endpoint
  ) : null
}