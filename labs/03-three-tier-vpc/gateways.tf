resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-igw"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "three-tier-vpc-lab-dev-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = aws_subnet.this["public_a"].id
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "three-tier-vpc-lab-dev-nat"
  }
}
