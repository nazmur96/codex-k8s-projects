resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = toset(["public_a", "public_b"])

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "api" {
  for_each = toset(["api_a", "api_b"])

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-${each.key}"
  }
}

resource "aws_route" "api_internet" {
  for_each = toset(["api_a", "api_b"])

  route_table_id         = aws_route_table.api[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "api" {
  for_each = toset(["api_a", "api_b"])

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.api[each.key].id
}

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-database"
  }
}

resource "aws_route_table_association" "database" {
  for_each = toset(["database_a", "database_b"])

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.database.id
}
