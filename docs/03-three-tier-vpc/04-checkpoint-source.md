# Complete checkpoint source — November 7, 2026

These are the complete files written so far for catalog #17, lab 03. This is an
**unfinished implementation**, not a ready-to-apply application. EC2 resources,
startup/bootstrap wiring, target registrations and state-backend selection are
still pending. See the [build checkpoint](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/03-three-tier-vpc/02-build-and-checkpoint.md).

All paths below are relative to `/workspaces/eks-lab/labs/03-three-tier-vpc`.
The source directory is authoritative; this snapshot records the teaching checkpoint.
Provider selection is AWS `6.72.0`, recorded in the committed `.terraform.lock.hcl`.


## `versions.tf`

```hcl
terraform {
  required_version = "= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

```

## `providers.tf`

```hcl
provider "aws" {
  region              = "eu-central-1"
  profile             = "authentik-tf"
  allowed_account_ids = ["750702271569"]

  default_tags {
    tags = {
      Project     = "three-tier-vpc-lab"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

```

## `vpc.tf`

```hcl
resource "aws_vpc" "this" {
  cidr_block           = "10.40.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "three-tier-vpc-lab-dev"
  }
}

```

## `subnets.tf`

```hcl
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

```

## `gateways.tf`

```hcl
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

```

## `routes.tf`

```hcl
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

```

## `endpoints.tf`

```hcl
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

```

## `security-groups.tf`

```hcl
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

```

## `security-group-rules.tf`

```hcl

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Internet HTTP to ALB"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id = aws_security_group.api.id
  description       = "ALB to API"

  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "database_from_api" {
  security_group_id = aws_security_group.database.id
  description       = "API to PostgreSQL"

  referenced_security_group_id = aws_security_group.api.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
resource "aws_vpc_security_group_egress_rule" "alb_to_api" {
  security_group_id = aws_security_group.alb.id
  description       = "ALB requests and health checks to API"

  referenced_security_group_id = aws_security_group.api.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "api_to_database" {
  security_group_id = aws_security_group.api.id
  description       = "API connections to PostgreSQL"

  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
resource "aws_vpc_security_group_egress_rule" "api_https" {
  security_group_id = aws_security_group.api.id
  description       = "API outbound HTTPS"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

```

## `alb.tf`

```hcl
resource "aws_lb" "this" {
  name               = "three-tier-vpc-lab-dev"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.this["public_a"].id,
    aws_subnet.this["public_b"].id,
  ]

  depends_on = [
    aws_internet_gateway.this,
    aws_route.public_internet,
    aws_route_table_association.public,
  ]

  tags = {
    Name = "three-tier-vpc-lab-dev-alb"
  }
}
resource "aws_lb_target_group" "api" {
  name        = "three-tier-api-dev"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "three-tier-vpc-lab-dev-api"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}


```

## `outputs.tf`

```hcl
output "vpc_id" {
  description = "ID of the lab VPC"
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "Subnet IDs indexed by their names"
  value = {
    for name, subnet in aws_subnet.this :
    name => subnet.id
  }
}

output "security_group_ids" {
  description = "Security group IDs for each tier"
  value = {
    alb      = aws_security_group.alb.id
    api      = aws_security_group.api.id
    database = aws_security_group.database.id
  }
}

output "alb_url" {
  description = "HTTP address of the lab ALB"
  value       = "http://${aws_lb.this.dns_name}"
}

output "api_target_group_arn" {
  description = "Target group ARN for checking API health"
  value       = aws_lb_target_group.api.arn
}


```

## `compute.tf`

```hcl

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ami" "al2023" {
  owners = ["amazon"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.al2023_ami.value]
  }
}

```

## `iam.tf`

```hcl
resource "aws_iam_role" "api" {
  name_prefix = "three-tier-api-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_ssm" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "api" {
  name_prefix = "three-tier-api-"
  role        = aws_iam_role.api.name
}

```

## `templates/api.py.tftpl`

Terraform template syntax on the database-host line is replaced before Python runs.

```python
import json
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DATABASE_HOST = ${jsonencode(database_host)}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        status = 200

        if self.path == "/health":
            result = {"status": "healthy"}
        elif self.path == "/":
            result = {"service": "three-tier-api", "host": socket.gethostname()}
        elif self.path == "/db":
            try:
                with socket.create_connection((DATABASE_HOST, 5432), timeout=3):
                    pass
                result = {"database_tcp": "reachable"}
            except OSError:
                status = 503
                result = {"database_tcp": "unreachable"}
        else:
            status = 404
            result = {"error": "not found"}

        body = json.dumps(result).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

```
