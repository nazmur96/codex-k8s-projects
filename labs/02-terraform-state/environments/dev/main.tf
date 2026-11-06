module "network" {
  source = "../../modules/network"

  environment = "dev"
  vpc_cidr    = "10.30.0.0/16"

  subnets = {
    private_a = {
      cidr_block        = "10.30.10.0/24"
      availability_zone = "eu-central-1a"
    }

    private_b = {
      cidr_block        = "10.30.11.0/24"
      availability_zone = "eu-central-1b"
    }
  }

  tags = {
    Project   = "terraform-state-lab"
    ManagedBy = "Terraform"
    Exercise  = "state-locking"
  }
}
