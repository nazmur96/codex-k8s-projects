resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.api["api_a"].id,
    aws_route_table.api["api_b"].id,
  ]

  tags = {
    Name = "three-tier-vpc-lab-dev-s3"
  }
}
