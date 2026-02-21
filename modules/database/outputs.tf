output "db_endpoint" {
  value = var.db_engine == "aurora" ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.postgres[0].address
}

output "db_reader_endpoint" {
  value = var.db_engine == "aurora" ? aws_rds_cluster.aurora[0].reader_endpoint : (length(aws_db_instance.replica) > 0 ? aws_db_instance.replica[0].address : null)
}
