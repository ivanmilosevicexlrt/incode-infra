output "db_endpoint" {
  value = var.db_engine == "aurora" ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.postgres[0].address
}

#non-prod instances are not using replica so output will be empty
output "db_reader_endpoint" {
  value = var.db_engine == "aurora" ? aws_rds_cluster.aurora[0].reader_endpoint : null
}