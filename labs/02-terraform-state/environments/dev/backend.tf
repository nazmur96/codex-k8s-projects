terraform {
  backend "s3" {
    bucket = "nazmur96-tfstate-750702271569-euc1"
    key    = "project-16/dev/terraform.tfstate"
    region = "eu-central-1"

    profile             = "authentik-tf"
    allowed_account_ids = ["750702271569"]

    encrypt      = true
    use_lockfile = true
  }
}
