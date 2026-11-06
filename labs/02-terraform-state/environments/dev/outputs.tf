output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "Dev subnet IDs keyed by subnet name."
  value       = module.network.subnet_ids
}
