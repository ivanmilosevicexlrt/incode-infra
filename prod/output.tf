output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_reader_endpoint" {
  value = module.database.db_reader_endpoint
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

# output "cluster_ca_data" {
#   value = module.eks.cluster_ca_data
# }

output "cluster_ca_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  value = module.eks.cluster_name
}
output "cluster_version" {
  value = module.eks.cluster_version
}


output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}