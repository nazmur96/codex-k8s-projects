# Build the lab step by step

This records the November 8, 2026 session. The learner wrote every file and ran
every project command, one small step at a time. Everything below is the final
committed code. Do not reapply blindly: start from a fresh plan, and ask before
every apply or destroy.

## 1. Environment and identity

**Host terminal:** start the existing workspace and connect.

```sh
devpod up eks-lab --ide none
ssh eks-lab.devpod
```

**Container terminal:**

```sh
cd /workspaces/eks-lab
mise exec -- aws login --profile authentik --region eu-central-1 --remote
mise exec -- aws sts get-caller-identity \
  --profile authentik-tf --region eu-central-1 --no-cli-pager
```

Expected account `750702271569`, role `AuthentikAdmin`. Agent-captured:
`arn:aws:sts::750702271569:assumed-role/AuthentikAdmin/akadmin`.

## 2. Versions and provider

```sh
mkdir -p /workspaces/eks-lab/labs/04-security-groups
cd /workspaces/eks-lab/labs/04-security-groups
```

`versions.tf`:

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

`providers.tf`:

```hcl
provider "aws" {
  region              = "eu-central-1"
  profile             = "authentik-tf"
  allowed_account_ids = ["750702271569"]

  default_tags {
    tags = {
      Project     = "security-groups-lab"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
```

`allowed_account_ids` makes Terraform refuse to run against any other account.

```sh
mise exec -- terraform fmt
mise exec -- terraform init
```

`init` selected AWS provider `6.72.0` (see `.terraform.lock.hcl`). It downloads
the provider and creates nothing in AWS.

## 3. VPC and subnets

`vpc.tf`:

```hcl
resource "aws_vpc" "this" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "security-groups-lab-dev"
  }
}
```

`subnets.tf`:

```hcl
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
```

`10.50.x` avoids confusion with lab 03's `10.40.x`. No subnet hands out public
IPs; the ALB receives its own.

## 4. Internet gateway and route tables

`gateways.tf`:

```hcl
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev"
  }
}
```

`routes.tf`:

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "security-groups-lab-dev-private"
  }
}

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = each.value.tier == "public" ? aws_route_table.public.id : aws_route_table.private.id
}
```

| Table | Routes | Used by |
| --- | --- | --- |
| `public` | local + `0.0.0.0/0 → IGW` | `public_a`, `public_b` |
| `private` | local only | `private_a` |

## 5. Security groups

Five groups with no inline rules. Every allowed path is a separate rule
resource, so a plan shows each one, and one can be removed without touching
the group.

`security-groups.tf`:

```hcl
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
```

## 6. Traffic rules

`security-group-rules.tf`:

```hcl
# Path 1: internet -> ALB
resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb.id
  description       = "Internet HTTP to ALB"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

# Path 2: ALB -> app
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id
  description       = "ALB requests and health checks to app"

  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id
  description       = "ALB to app"

  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

# Path 3: app -> db
resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id = aws_security_group.app.id
  description       = "App connections to database"

  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.db.id
  description       = "App to database"

  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
```

| Setting | Meaning |
| --- | --- |
| `security_group_id` | the SG the rule belongs to |
| `referenced_security_group_id` | the other side: any interface with that SG attached |
| `cidr_ipv4` | the other side as an IP range (the internet, or the VPC) |
| `from_port` / `to_port` | port range; equal values mean one port |

## 7. Admin SSH and probe rules

`access-rules.tf`:

```hcl
locals {
  ssh_targets = {
    app   = aws_security_group.app.id
    db    = aws_security_group.db.id
    probe = aws_security_group.probe.id
  }
}

# Admin SSH: connect endpoint -> each instance
resource "aws_vpc_security_group_egress_rule" "eice_ssh_out" {
  for_each = local.ssh_targets

  security_group_id = aws_security_group.eice.id
  description       = "Connect endpoint SSH to ${each.key}"

  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_eice" {
  for_each = local.ssh_targets

  security_group_id = each.value
  description       = "SSH from connect endpoint"

  referenced_security_group_id = aws_security_group.eice.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# Probe may send anything inside the VPC, so blocks happen at the destination
resource "aws_vpc_security_group_egress_rule" "probe_all_vpc" {
  security_group_id = aws_security_group.probe.id
  description       = "Probe any TCP inside the VPC"

  cidr_ipv4   = aws_vpc.this.cidr_block
  ip_protocol = "tcp"
  from_port   = 0
  to_port     = 65535
}
```

`for_each` over `ssh_targets` turns six near-identical rules into two blocks.
`probe_all_vpc` makes sure a blocked probe is blocked at the destination, not
at its own SG.

## 8. Instances

`compute.tf`:

```hcl
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  instances = {
    app = {
      sg   = aws_security_group.app.id
      port = 8080
    }
    db = {
      sg   = aws_security_group.db.id
      port = 5432
    }
    probe = {
      sg   = aws_security_group.probe.id
      port = null
    }
  }
}

resource "aws_instance" "this" {
  for_each = local.instances

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.this["private_a"].id
  vpc_security_group_ids      = [each.value.sg]
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data_replace_on_change = true
  user_data                   = each.value.port == null ? null : <<-EOT
    #!/bin/bash
    mkdir -p /srv/www
    echo "hello from ${each.key}" > /srv/www/index.html
    systemd-run --unit=lab-listener --uid=nobody \
      python3 -m http.server ${each.value.port} --directory /srv/www
  EOT

  tags = {
    Name = "security-groups-lab-dev-${each.key}"
  }
}
```

| Setting | Why |
| --- | --- |
| `aws_ssm_parameter` | current Amazon Linux 2023 image ID; nothing hard-coded |
| one `subnet_id` for all | same subnet and routes, so only SGs differ |
| `associate_public_ip_address = false` | unreachable from the internet; no public IP charge |
| `http_tokens = "required"` | IMDSv2 |
| `encrypted = true` | encrypted root disk, free |
| `systemd-run --uid=nobody` | listener runs as a powerless user. It is a transient unit and does not survive a reboot, which is fine for a same-day lab |
| `user_data_replace_on_change` | an edited script recreates the instance, so the new script runs |
| `port == null ? null : …` | the probe gets no startup script |

The "database" is Python's built-in web server on port 5432, not PostgreSQL.
The tests check only whether a TCP connection gets through. No packages are
installed, which matters because the private subnet has no internet route.

## 9. EC2 Instance Connect Endpoint

`endpoint.tf`:

```hcl
resource "aws_ec2_instance_connect_endpoint" "this" {
  subnet_id          = aws_subnet.this["private_a"].id
  security_group_ids = [aws_security_group.eice.id]
  preserve_client_ip = false

  tags = {
    Name = "security-groups-lab-dev"
  }
}
```

`preserve_client_ip = false` makes instances see the endpoint's private IP as
the source, so `ssh_from_eice` matches. See the concepts guide.

## 10. ALB

`alb.tf`:

```hcl
resource "aws_lb" "this" {
  name                       = "seclab-dev"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.this["public_a"].id, aws_subnet.this["public_b"].id]
  drop_invalid_header_fields = true

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "security-groups-lab-dev"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "seclab-app"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.this["app"].id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

`depends_on = [aws_internet_gateway.this]` is needed because an
internet-facing ALB fails to create without an attached IGW, and nothing in
the ALB references the IGW directly.

## 11. Outputs

`outputs.tf`:

```hcl
output "alb_url" {
  value = "http://${aws_lb.this.dns_name}"
}

output "instance_ids" {
  value = { for name, instance in aws_instance.this : name => instance.id }
}

output "private_ips" {
  value = { for name, instance in aws_instance.this : name => instance.private_ip }
}
```

## 12. Plan and apply

```sh
mise exec -- terraform fmt
mise exec -- terraform fmt -check && echo FMT_OK
mise exec -- terraform validate
mise exec -- terraform plan -out=lab04.tfplan
```

Agent-reviewed saved plan: `Plan: 36 to add, 0 to change, 0 to destroy.`

| Count | What |
| --- | --- |
| 11 | VPC, 3 subnets, IGW, 2 route tables, 1 route, 3 associations |
| 17 | 5 SGs + 12 rules |
| 3 | instances |
| 1 | Instance Connect Endpoint |
| 4 | ALB, target group, attachment, listener |

Checked in the plan: three `t3.micro` with no public IP, IMDSv2 required,
encrypted disks; every subnet with `map_public_ip_on_launch = false`;
`preserve_client_ip = false`; `internal = false` on the ALB. The image ID shows
as `(sensitive value)` because SSM parameter values are marked sensitive.

After cost review and learner approval:

```sh
mise exec -- terraform apply lab04.tfplan
```

Learner-reported: `Apply complete! Resources: 36 added, 0 changed, 0 destroyed.`
Agent-captured outputs: ALB `seclab-dev-880210536.eu-central-1.elb.amazonaws.com`;
private IPs app `10.50.10.179`, db `10.50.10.138`, probe `10.50.10.63`.

## Troubleshooting from this session

| Symptom | Cause | Fix |
| --- | --- | --- |
| `invalid value for name_prefix (cannot begin with sg-)` | `sg-` is reserved for SG IDs. The agent's first snippet used it. | Renamed prefixes to `seclab-`. Resource-ID prefixes (`sg-`, `vpc-`, `subnet-`) are never safe as names. |
| `validate`: provider `hashicorp/aws` isn't available | `init` had not completed in the lab folder | Re-ran `init` in the lab folder and confirmed `.terraform.lock.hcl` |
| `fmt -check` kept listing `compute.tf` | The snippet's `=` alignment differed from `fmt`'s; the fix did not persist at first | Ran `terraform fmt`, then `fmt -check && echo FMT_OK` to confirm |
| No `lab04.tfplan` after "plan" | `plan` ran without `-out` | Re-ran `plan -out=lab04.tfplan`, then `ls` to confirm the file exists |
| Vim `Ctrl+v` block selection did nothing | The terminal took `Ctrl+v` as paste | Use a range command, such as `:44,52s/^/# /` |
| Accidental file name `acceess-rules.tf` | Typo; Terraform reads any `.tf` name | `mv acceess-rules.tf access-rules.tf` |
