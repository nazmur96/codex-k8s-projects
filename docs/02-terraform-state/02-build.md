# Build the lab step by step

This records the completed session. Do not blindly reapply an existing deployment. Use fresh plans and inspect state first. Commands below create resources only where explicitly marked apply; obtain approval before every apply or destroy.

## 1. Reuse the existing environment

Project tools belong in the container, not on the NixOS host. The existing repo declares Terraform 1.17.1, AWS CLI 2.39.3 and kubectl 1.37.2 through mise. Kubectl is unused by this lab. Docker owns the runtime; DevPod manages the development container. The host checkout is mounted into the container, so project files persist even when a container stops or is recreated.

**Host terminal:**

```sh
cd ~/orca/projects/codex-k8s-projects
devpod list
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

If eks-lab is stopped, start the existing workspace, then connect:

```sh
devpod up . --id eks-lab --provider docker --ide none
ssh eks-lab.devpod
```

**DevPod terminal:**

```sh
cd /workspaces/eks-lab
cat mise.toml terraform/versions.tf
mise exec -- terraform version
```

The existing AWS directory is mounted at `/home/vscode/.aws`. Keep it out of Git. Renew authentication when required:

```sh
mise exec -- aws login --profile authentik --region eu-central-1 --remote
mise exec -- aws sts get-caller-identity --profile authentik-tf --region eu-central-1
```

Complete browser approval privately. Expected account: 750702271569; role: AuthentikAdmin. The remote login flow avoids a host-browser/container-localhost callback mismatch. Do not share login URLs, codes or tokens.

Before new billed work, check the existing account-wide budget rather than creating another one:

```sh
mise exec -- aws budgets describe-budgets \
  --account-id 750702271569 --profile authentik-tf --region eu-central-1 \
  --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit,Actual:CalculatedSpend.ActualSpend,Forecast:CalculatedSpend.ForecastedSpend,Filters:CostFilters}' \
  --no-cli-pager
```

A null Filters result means no cost filters on that budget. Budget figures can lag actual use. This does not check notification delivery. S3 charges for stored data, versions and requests; light lab use is expected to be small, not guaranteed free. SSE-S3 has no additional encryption fee. See [AWS pricing](https://aws.amazon.com/s3/pricing/) and [SSE-S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingServerSideEncryption.html).

## 2. Create the directory structure

**DevPod terminal, repository root:**

```sh
mkdir -p labs/02-terraform-state/{bootstrap,modules/network,environments/dev}
ls -R labs/02-terraform-state
```

Brace expansion produces three paths. `mkdir -p` also creates missing parents. Lab 02 is master catalog #16; lab 01 was catalog #23. The old EKS configuration stays in `terraform/`.

## 3. Write the files

For each file below, enter its indicated directory, run `vim filename`, press `i`, paste the complete contents, then press Escape, type `:wq`, and press Enter. You can use any editor already available; installing another is unnecessary.

These are the actual final implementation files. The Exercise tag was added later for the locking drill. For an exact replay, omit that one line initially and add it during the drill.

Bucket names and account IDs below are specific to this lab. A different user must select their own globally unique bucket name and update both provider account checks and backend configuration. Do not import or take ownership of someone else's bucket after a name-conflict error.

### Directory: `labs/02-terraform-state/bootstrap`

#### `main.tf`

```hcl
resource "aws_s3_bucket" "state" {
  bucket        = "nazmur96-tfstate-750702271569-euc1"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
```

#### `outputs.tf`

```hcl
output "state_bucket_name" {
  description = "S3 bucket used to store this lab's Terraform state."
  value       = aws_s3_bucket.state.id
}
```

#### `providers.tf`

```hcl
provider "aws" {
  region              = "eu-central-1"
  profile             = "authentik-tf"
  allowed_account_ids = ["750702271569"]

  default_tags {
    tags = {
      Project     = "terraform-state-lab"
      Environment = "bootstrap"
      ManagedBy   = "Terraform"
    }
  }
}
```

#### `versions.tf`

```hcl
terraform {
  required_version = "= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

### Directory: `labs/02-terraform-state/modules/network`

#### `main.tf`

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name        = "tfstate-lab-${var.environment}-vpc"
    Environment = var.environment
  })
}

resource "aws_subnet" "main" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name        = "tfstate-lab-${var.environment}-${each.key}"
    Environment = var.environment
  })
}
```

#### `outputs.tf`

```hcl
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
```

#### `variables.tf`

```hcl
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
```

#### `versions.tf`

```hcl
terraform {
  required_version = "= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

### Directory: `labs/02-terraform-state/environments/dev`

#### `backend.tf`

```hcl
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
```

#### `main.tf`

```hcl
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
```

#### `outputs.tf`

```hcl
output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "Dev subnet IDs keyed by subnet name."
  value       = module.network.subnet_ids
}
```

#### `providers.tf`

```hcl
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
```

#### `versions.tf`

```hcl
terraform {
  required_version = "= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

## 4. Initialize and apply bootstrap first

**DevPod terminal:**

```sh
cd /workspaces/eks-lab/labs/02-terraform-state/bootstrap
mise exec -- terraform fmt
mise exec -- terraform init
mise exec -- terraform validate
mise exec -- terraform plan -out=bootstrap.tfplan
```

Init downloads providers and writes the provider lock file. Validate checks configuration structure, not all AWS conditions. Expected plan: 4 added, 0 changed, 0 destroyed. They are one bucket plus three separately managed settings, not four buckets.

Review the whole plan, account, costs and budget. **Only after approval:**

```sh
mise exec -- terraform apply bootstrap.tfplan
```

Saved-plan apply executes immediately without another yes prompt. Actual supplied result: 4 added, 0 changed, 0 destroyed. Keep the local bootstrap state private and preserve it for managing this bucket.

Verify versioning through AWS:

```sh
mise exec -- aws s3api get-bucket-versioning \
  --bucket nazmur96-tfstate-750702271569-euc1 \
  --profile authentik-tf --region eu-central-1 --no-cli-pager
```

Expected and learner-confirmed: Status Enabled. Encryption and public-access settings were present in the reviewed plan and successful apply; separate readback output was not captured.

`prevent_destroy` blocks plans that would destroy/replace the bucket while the rule remains configured. It does not prevent manual AWS deletion. `force_destroy = false` refuses automatic removal of bucket contents. These are deliberate protections for valuable state.

## 5. Initialize and apply dev

**DevPod terminal:**

```sh
cd /workspaces/eks-lab/labs/02-terraform-state
mise exec -- terraform fmt -recursive
mise exec -- terraform fmt -check -recursive
cd environments/dev
mise exec -- terraform init
mise exec -- terraform validate
mise exec -- terraform plan -out=dev.tfplan
mise exec -- terraform show -no-color dev.tfplan
```

Init configures S3 and loads the child module. This root was new, so there was no existing network state to migrate. Do not move an existing state to another backend by simply copying backend settings; migrations require separate planning.

Expected plan: one VPC and two subnets, 3 added, 0 changed, 0 destroyed. Check CIDRs, zones, tags and absence of unrelated changes. **Only after approval:**

```sh
mise exec -- terraform apply dev.tfplan
```

Captured result: 3 added, 0 changed, 0 destroyed. Resource IDs were not captured in the session and are not invented here. Read them privately with `terraform output` when needed.

The final tracked source includes the Exercise tag from the later drill. An initial deployment from this final source creates resources with that tag already present.

Continue with the proof and cleanup guide. A successful apply alone does not finish the project.
