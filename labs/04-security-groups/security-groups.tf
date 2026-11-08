resource "aws_security_group" "alb" {
  name_prefix = "seclab-alb-"
  description = "Public entry point"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-alb"
  }
}

resource "aws_security_group" "app" {
  name_prefix = "seclab-app-"
  description = "Application tier"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-app"
  }
}

resource "aws_security_group" "db" {
  name_prefix = "seclab-db-"
  description = "Database tier"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-db"
  }
}

resource "aws_security_group" "probe" {
  name_prefix = "seclab-probe-"
  description = "Unauthorized test source in the same subnet"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-probe"
  }
}

resource "aws_security_group" "eice" {
  name_prefix = "seclab-eice-"
  description = "EC2 Instance Connect Endpoint"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-eice"
  }
}
