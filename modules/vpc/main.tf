resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

#node registration will go over the one NAT gateway and public IP (not ideal)
#there will be only one  public subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_subnet" "public_subnet_for_nat" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 100)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                                    = "${var.name}-public-${data.aws_availability_zones.available.names[0]}"
    Tier                                    = "public"
    "kubernetes.io/role/elb"                = "1"
    "kubernetes.io/cluster/${var.name}-eks" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table_association" "public_nat" {
  subnet_id      = aws_subnet.public_subnet_for_nat.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = var.enable_nat ? 1 : 0
  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_subnet_for_nat.id

  tags = {
    Name = "${var.name}-nat"
  }
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_subnet" "app" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                    = "${var.name}-app-${data.aws_availability_zones.available.names[count.index]}"
    Tier                                    = "application"
    "kubernetes.io/role/internal-elb"       = "1"
    "kubernetes.io/cluster/${var.name}-eks" = "shared"
  }
}

# Private route table with NAT Gateway route
resource "aws_route_table" "app_private_rt" {
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat_gateway[0].id
    }
  }

  tags = {
    Name = "${var.name}-app-private-rt"
  }
}

# Associate the app subnets with the NAT route table
resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app_private_rt.id
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

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = {
    Name = "${var.name}-db-subnet-group"
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


