output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_reader_endpoint" {
  value = module.database.db_reader_endpoint
}

output "private_subnet_ids" {
  value = module.vpc.db_subnets
}
