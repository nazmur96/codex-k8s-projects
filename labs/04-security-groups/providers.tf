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
