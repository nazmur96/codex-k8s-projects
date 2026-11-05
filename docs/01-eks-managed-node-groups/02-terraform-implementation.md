# Terraform implementation, step by step

All commands in this guide run in the **devcontainer** unless marked otherwise. We wrote the following files incrementally, explained each resource, and ran formatting and validation throughout. These are full source snapshots at this checkpoint.

## Create the Terraform directory

```sh
mkdir -p terraform
vim terraform/versions.tf
vim terraform/providers.tf
cd /workspaces/eks-lab/terraform
mise exec -- terraform init
mise exec -- terraform fmt
mise exec -- terraform validate
```

We initially wrote only versions and provider configuration, initialized successfully, and validated before adding infrastructure. `init` downloads providers into ignored `.terraform/` and writes the committed `.terraform.lock.hcl`. An empty `fmt` output means no formatting changes were needed. `validate` printed `Success! The configuration is valid.` It checks configuration, not live AWS functionality.

For each remaining file, use `vim <filename>` in this directory. Press `i` to paste a new file; to append, press Escape, `G`, then `o`. Save with Escape, `:wq`, Enter. Run `mise exec -- terraform fmt` and `mise exec -- terraform validate` after changes. File-writing order was network, cluster/node/CNI IAM roles, admin CIDR variables, cluster, access entries, node group, then add-ons.

## Terraform and provider versions — `versions.tf`

`required_version` requires Terraform 1.17.1. `~> 6.0` permits AWS provider 6.x; `.terraform.lock.hcl` records the actual selected provider version and checksums. The lock file is committed; downloaded plugins are not.

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

## AWS provider and resource tags — `providers.tf`

The provider uses Frankfurt (`eu-central-1`) and the existing `authentik-tf` profile. `allowed_account_ids` guards against deployment into another account. Default Project, ManagedBy, and Purpose tags apply to supported resources. Account IDs and role ARNs identify resources; they are not credentials.

```hcl
provider "aws" {
  region  = "eu-central-1"
  profile = "authentik-tf"

  allowed_account_ids = ["750702271569"]

  default_tags {
    tags = {
      Project   = "eks-managed-node-groups"
      ManagedBy = "Terraform"
      Purpose   = "Learning"
    }
  }
}
```

## VPC, subnets, gateways, and routing — `network.tf`

The VPC range is `10.20.0.0/16`, spanning 10.20.0.0–10.20.255.255. DNS support and hostnames are enabled. Four /24 subnets divide that range without overlap: public A 10.20.0.0/24, public B 10.20.1.0/24, private A 10.20.10.0/24, private B 10.20.11.0/24. A/B refer to eu-central-1a/eu-central-1b. Each subnet belongs to one Availability Zone. Terraform references such as `aws_vpc.main.id` express dependencies.

An internet gateway attaches to the VPC. Both public subnets explicitly associate with the public route table, whose `0.0.0.0/0` route targets the internet gateway. AWS supplies the more specific local VPC route automatically. A public route alone does not give an instance internet connectivity: addressing and security rules also matter.

An Elastic IP supplies the NAT gateway’s public IPv4 address. NAT is placed in public subnet A. Both private subnets associate with the private route table, whose default route targets NAT. Private nodes can initiate outbound connections without public IPs; NAT does not permit unsolicited inbound connections. Explicit NAT dependencies establish the public internet path first. One shared NAT reduces lab cost but creates an AZ-A dependency and possible cross-AZ transfer charges.

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.20.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks-lab-vpc"
  }
}
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.0.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "eks-lab-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "eks-lab-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.10.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "eks-lab-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.11.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "eks-lab-private-b"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks-lab-igw"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks-lab-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "eks-lab-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [
    aws_internet_gateway.main,
    aws_route.public_internet,
    aws_route_table_association.public_a
  ]

  tags = {
    Name = "eks-lab-nat"
  }
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "eks-lab-private-rt"
  }
}

resource "aws_route" "private_internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
```

## Cluster, node, and pod IAM roles — `iam.tf`

A trust policy answers who may assume a role; permission policies answer what the resulting session may do. `jsonencode` emits IAM JSON from Terraform expressions. `2012-10-17` is the policy-language version, not the creation date.

The cluster role trusts `eks.amazonaws.com` and receives AmazonEKSClusterPolicy. The node role trusts `ec2.amazonaws.com` and receives AmazonEKSWorkerNodePolicy plus AmazonEC2ContainerRegistryPullOnly. These support node AWS discovery, Pod Identity agent access, and private ECR image downloads subject to repository access.

The separate VPC CNI role trusts `pods.eks.amazonaws.com`, permits sts:AssumeRole and sts:TagSession, and receives AmazonEKS_CNI_Policy for IPv4 networking. Keeping CNI network-interface/IP permissions separate avoids adding those permissions to the node role. A role alone does not grant all pods access; a specific Pod Identity association is required.

```hcl
resource "aws_iam_role" "cluster" {
  name = "eks-lab-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role" "node" {
  name = "eks-lab-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}
resource "aws_iam_role" "vpc_cni" {
  name = "eks-lab-vpc-cni-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
```

## Local administrator CIDR input — `variables.tf`

This declares the required string input. The actual public IP is supplied in an ignored `terraform.tfvars`; a sanitized example is committed. `/32` restricts public endpoint access to one IPv4 address.

```hcl
variable "admin_cidr" {
  description = "Public IPv4 CIDR allowed to reach the EKS API endpoint."
  type        = string
}
```

## EKS control plane — `cluster.tf`

The selected version is 1.37. `role_arn` supplies the cluster IAM role. EKS creates VPC interfaces in our private subnets; the control plane itself runs in AWS-managed infrastructure. Private API access supports nodes inside the VPC; restricted public API access supports our development container.

Self-managed bootstrap add-ons are disabled because Terraform manages the add-ons explicitly. API authentication enables EKS access entries. Automatic creator-admin access is disabled so the administrator grant is explicit. The IAM policy attachment dependency ensures role permissions exist before cluster creation.

```hcl
resource "aws_eks_cluster" "main" {
  name     = "eks-lab"
  version  = "1.37"
  role_arn = aws_iam_role.cluster.arn

  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.admin_cidr]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]
}
```

## Kubernetes administrator access — `access.tf`

The permanent IAM role ARN is registered through a STANDARD access entry, then associated with AmazonEKSClusterAdminPolicy at cluster scope. This EKS access policy controls Kubernetes permissions; it is different from an IAM permission policy. Network reachability does not authorize API actions. Production teams commonly grant narrower access to developer roles.

```hcl
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::750702271569:role/AuthentikAdmin"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.admin.principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
```

## Managed EC2 workers — `nodes.tf`

The managed node group uses private subnets, the node role, Amazon Linux 2023 x86_64 EKS images, and two On-Demand t3.medium instances (2 vCPU and 4 GiB RAM each). Each root disk is 20 GiB. Desired/minimum/maximum capacity is 2/1/2. These bounds do not install an autoscaler.

`max_unavailable = 1` limits unavailable nodes during managed updates. EKS handles node provisioning/replacement and coordinates updates we request; we still choose capacity and update settings. Dependencies ensure node IAM attachments and private outbound routing are established first.

```hcl
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "eks-lab-workers"
  node_role_arn   = aws_iam_role.node.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  version        = aws_eks_cluster.main.version
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr,
    aws_route.private_internet,
    aws_route_table_association.private_a,
    aws_route_table_association.private_b
  ]
}
```

## Managed add-ons and Pod Identity — `addons.tf`

VPC CNI supplies pod networking; CoreDNS supplies cluster DNS; kube-proxy configures Service traffic rules; Pod Identity Agent supplies temporary AWS credentials to associated workloads. Versions were queried from AWS for Kubernetes 1.37 and pinned.

The association maps namespace `kube-system`, service account `aws-node`, to the CNI role. Service accounts are Kubernetes identities used by pods. CNI creation waits for its role association; CoreDNS creation waits for the node group. The agent, networking add-ons, and nodes may bootstrap concurrently. Terraform dependencies do not replace runtime health checks: verify the agent, CNI, nodes, and DNS after apply.

```hcl
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.4.1-eksbuild.3"
}

resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni.arn

  depends_on = [
    aws_iam_role_policy_attachment.vpc_cni
  ]
}


resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.22.4-eksbuild.10"

  depends_on = [
    aws_eks_pod_identity_association.vpc_cni
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = "v1.37.0-eksbuild.32"
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = "v1.14.7-eksbuild.22"

  depends_on = [
    aws_eks_node_group.main
  ]
}
```

## Supply the local IP value

```sh
vim terraform.tfvars
```

Use your actual outbound public IPv4 address, followed by `/32`. Example only:

```hcl
admin_cidr = "203.0.113.10/32"
```

This file is ignored. `terraform.tfvars.example` is a sanitized template; do not mistake its documentation-only IP for a usable allowlist value.

## Network filtering choices

No custom NACL was written. AWS creates the default VPC NACL allowing traffic; NACLs filter at subnet boundaries. No custom security groups or launch template were written. EKS creates its cluster security group and, for this managed node group configuration, attaches it to workers. Security groups filter traffic for attached interfaces. Inspect their actual rules after deployment. We do not open SSH to nodes. The public API CIDR restriction is separate from these controls.

## Expected traffic paths

```text
Private node → private route table → NAT in public A → internet gateway → internet
Private node → private EKS API endpoint
Devcontainer → permitted public IP → public EKS API → IAM authentication/access policy
CNI pod → Pod Identity Agent → associated CNI IAM role → AWS networking APIs
```
