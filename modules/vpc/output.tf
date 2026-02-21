
output "vpc_id" {
  value = aws_vpc.this.id
}

output "app_subnets" {
  value = aws_subnet.app[*].id
}

output "db_subnets" {
  value = aws_subnet.db[*].id
}

output "db_subnet_group" {
  description = "Name of the DB subnet group for RDS"
  value       = aws_db_subnet_group.this.name
}

output "monitoring_subnets" {
  value = aws_subnet.monitoring[*].id
}