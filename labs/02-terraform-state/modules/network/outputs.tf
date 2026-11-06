output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Subnet IDs keyed by the input subnet names."
  value = {
    for name, subnet in aws_subnet.main : name => subnet.id
  }
}
