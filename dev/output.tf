output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

# Uncomment when database module is enabled
# output "db_endpoint" {
#   value = module.database.db_endpoint
# }
#
# output "db_reader_endpoint" {
#   value = module.database.db_reader_endpoint
# }
