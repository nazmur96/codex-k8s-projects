provider "aws" {
  region              = "eu-central-1"
  profile             = "authentik-tf"
  allowed_account_ids = ["750702271569"]

  default_tags {
    tags = {
      Project     = "terraform-state-lab"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
