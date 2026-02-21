
output "vpc_id" {
  value = aws_vpc.this.id
}

output "app_subnets" {
  value = aws_subnet.app[*].id
}

output "db_subnets" {
  value = aws_subnet.db[*].id
}

output "monitoring_subnets" {
  value = aws_subnet.monitoring[*].id
}