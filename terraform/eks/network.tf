data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  public_subnets = {
    a = {
      availability_zone = data.aws_availability_zones.available.names[0]
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0)
    }
    b = {
      availability_zone = data.aws_availability_zones.available.names[1]
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.project_name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.project_name
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}
