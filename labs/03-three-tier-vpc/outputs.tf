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
