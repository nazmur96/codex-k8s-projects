resource "aws_ec2_instance_connect_endpoint" "this" {
  subnet_id          = aws_subnet.this["private_a"].id
  security_group_ids = [aws_security_group.eice.id]
  preserve_client_ip = false

  tags = {
    Name = "security-groups-lab-dev"
  }
}
