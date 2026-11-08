output "alb_url" {
  value = "http://${aws_lb.this.dns_name}"
}

output "instance_ids" {
  value = { for name, instance in aws_instance.this : name => instance.id }
}

output "private_ips" {
  value = { for name, instance in aws_instance.this : name => instance.private_ip }
}
