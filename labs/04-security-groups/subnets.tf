locals {
  subnets = {
    public_a = {
      cidr = "10.50.0.0/24"
      az   = "eu-central-1a"
      tier = "public"
    }
    public_b = {
      cidr = "10.50.1.0/24"
      az   = "eu-central-1b"
      tier = "public"
    }
    private_a = {
      cidr = "10.50.10.0/24"
      az   = "eu-central-1a"
      tier = "private"
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
    Name = "security-groups-lab-dev-${each.key}"
    Tier = each.value.tier
  }
}
