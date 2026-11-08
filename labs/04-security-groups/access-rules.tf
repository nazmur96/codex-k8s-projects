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
