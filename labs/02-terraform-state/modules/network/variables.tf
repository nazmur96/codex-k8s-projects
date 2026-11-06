variable "environment" {
  description = "Environment name used in resource tags."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "subnets" {
  description = "Subnets keyed by name, each with a CIDR and availability zone."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "tags" {
  description = "Common tags applied to networking resources."
  type        = map(string)
  default     = {}
}
