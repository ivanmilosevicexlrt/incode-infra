resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "app" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}-app-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "application"
  }
}

resource "aws_subnet" "db" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}-db-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "database"
  }
}

resource "aws_subnet" "monitoring" {
  count             = var.enable_monitoring ? var.az_count : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name}-mon-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "monitoring"
  }
}

# resource "aws_nat_gateway" "this" {
#   count         = var.enable_nat ? var.az_count : 0
#   subnet_id     = element(aws_subnet.app[*].id, count.index)
#   allocation_id = aws_eip.nat[count.index].id
#   tags = {
#     Name = "${var.name}-nat-${count.index}"
#   }
# }

