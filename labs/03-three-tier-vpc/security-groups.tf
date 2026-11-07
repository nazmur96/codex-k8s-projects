resource "aws_security_group" "alb" {
  name_prefix = "three-tier-alb-"
  description = "Public entry point for the lab"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-alb"
  }
}

resource "aws_security_group" "api" {
  name_prefix = "three-tier-api-"
  description = "Private API tier"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-api"
  }
}

resource "aws_security_group" "database" {
  name_prefix = "three-tier-database-"
  description = "Isolated database tier"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "three-tier-vpc-lab-dev-database"
  }
}
