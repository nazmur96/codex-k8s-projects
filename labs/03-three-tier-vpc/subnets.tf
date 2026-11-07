locals {
  subnets = {
    public_a = {
      cidr = "10.40.0.0/24"
      az   = "eu-central-1a"
      tier = "public"
    }
    public_b = {
      cidr = "10.40.1.0/24"
      az   = "eu-central-1b"
      tier = "public"
    }
    api_a = {
      cidr = "10.40.10.0/24"
      az   = "eu-central-1a"
      tier = "api"
    }
    api_b = {
      cidr = "10.40.11.0/24"
      az   = "eu-central-1b"
      tier = "api"
    }
    database_a = {
      cidr = "10.40.20.0/24"
      az   = "eu-central-1a"
      tier = "database"
    }
    database_b = {
      cidr = "10.40.21.0/24"
      az   = "eu-central-1b"
      tier = "database"
    }
  }
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name = "three-tier-vpc-lab-dev-${each.key}"
    Tier = each.value.tier
  }
}
