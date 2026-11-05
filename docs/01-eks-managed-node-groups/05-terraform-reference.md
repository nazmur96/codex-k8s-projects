# Terraform reference: every component and its purpose

This is a quick reference for our EKS lab. These items describe the intended configuration; they do not prove successful deployment. See the deployment guide for recorded results.

## Terraform basics

| Item | Purpose |
| --- | --- |
| `resource` | Declares an infrastructure object Terraform should manage. |
| Resource label, such as `main` | Gives an object a local Terraform name, such as `aws_vpc.main`. |
| `.id` | References an object's AWS identifier, such as a subnet ID. |
| `.arn` | References an object's full AWS resource name, commonly used for roles and policies. |
| `depends_on` | Explicitly requires another resource to finish before this resource is created. |
| `jsonencode` | Converts Terraform expressions into JSON, used for IAM trust policies. |
| `tags` | Adds labels to identify and organize AWS resources. |
| `variable` | Declares an input accepted by our configuration. |
| `terraform.tfvars` | Supplies local input values; ours contains the administrator IP range and is excluded from Git. |

## Configuration, providers, and state

| Item | Purpose |
| --- | --- |
| `required_version` | Requires Terraform 1.17.1 for this configuration. |
| `required_providers` | Declares the provider plugins Terraform needs. |
| `hashicorp/aws` | Supplies AWS resource types and API integration. |
| Provider version `~> 6.0` | Allows AWS provider releases from 6.0 up to, but excluding, 7.0. |
| Provider `region` | Selects Frankfurt, `eu-central-1`, for regional resources. |
| Provider `profile` | Uses `authentik-tf` for AWS authentication. |
| `allowed_account_ids` | Stops the provider from operating against an unintended AWS account. |
| `default_tags` | Applies project labels to supported resources automatically. |
| `.terraform.lock.hcl` | Records the selected provider version and checksums; committed to Git. |
| `.terraform/` | Holds downloaded providers and initialization metadata; excluded from Git. |
| Local state | Records which real AWS objects belong to our Terraform resources. |
| Saved plan | Records the proposed changes reviewed before apply; excluded from Git. |
| State lock | Prevents concurrent operations from writing the same state; distinct from the provider lock file. |
| Remote backend | Would store state elsewhere, such as S3; not configured for this lab. |
| S3 `use_lockfile = true` | Enables native S3 backend locking when using that backend; not enabled by default. |

## VPC and subnets

| Item | Purpose |
| --- | --- |
| VPC | Provides the private AWS network containing subnets and cluster network interfaces. |
| VPC `cidr_block` | Reserves `10.20.0.0/16`, spanning 10.20.0.0–10.20.255.255. |
| `enable_dns_support` | Enables DNS resolution through the VPC's AWS-provided resolver. |
| `enable_dns_hostnames` | Enables AWS DNS hostname support in the VPC. |
| Availability Zone | Places resources in an isolated location within the AWS region. |
| Public subnet A | Provides `10.20.0.0/24` in AZ A, including the NAT gateway's location. |
| Public subnet B | Provides `10.20.1.0/24` in AZ B; currently has no planned application resources. |
| Private subnet A | Provides `10.20.10.0/24` for private cluster interfaces and worker capacity in AZ A. |
| Private subnet B | Provides `10.20.11.0/24` for private cluster interfaces and worker capacity in AZ B. |
| Subnet `vpc_id` | Places the subnet inside our VPC. |
| `availability_zone` | Chooses the AZ containing a subnet. |
| `subnet_ids` | Tells a resource which subnets it may use; the meaning depends on the resource. |

## Routing and internet access

| Item | Purpose |
| --- | --- |
| Internet gateway | Connects the VPC to the internet when addressing, routes, and security rules permit. |
| Public route table | Holds routing rules shared by our public subnets. |
| Private route table | Holds routing rules shared by our private subnets. |
| Local route | Automatically routes traffic between addresses inside the VPC. |
| `destination_cidr_block = "0.0.0.0/0"` | Matches IPv4 destinations not handled by a more specific route. |
| Public internet route | Sends public-subnet internet traffic to the internet gateway. |
| Private internet route | Sends private-subnet internet traffic to the NAT gateway. |
| Route-table association | Explicitly assigns a route table to a subnet. |
| Route `gateway_id` | Identifies the internet gateway as the route's target. |
| Route `nat_gateway_id` | Identifies the NAT gateway as the route's target. |
| Elastic IP / EIP | Reserves the public IPv4 address used by our NAT gateway. |
| EIP `domain = "vpc"` | Allocates the Elastic IP for use with VPC resources. |
| NAT `allocation_id` | Selects which allocated Elastic IP the NAT gateway uses. |
| NAT `subnet_id` | Places our NAT gateway in public subnet A. |
| NAT gateway | Lets private nodes initiate outbound IPv4 connections without having public IPs. |

```text
Private node → private route table → NAT → internet gateway → internet
```

The shared NAT reduces lab cost but creates an AZ-A dependency and possible cross-AZ traffic charges. NAT permits response traffic to outbound connections, not unsolicited inbound internet connections.

## Network filtering

| Item | Purpose |
| --- | --- |
| NACL | Applies stateless subnet-boundary filtering; we retain the default VPC NACL, initially allowing traffic. |
| Security group / SG | Applies stateful filtering to attached network interfaces. |
| EKS cluster security group | Is created by EKS and supports control-plane/node communication. |
| Managed-node SG attachment | Uses the EKS cluster SG with our configuration, which has no custom launch template. |
| Custom SGs/NACLs | Are not defined in our Terraform; AWS-created rules still require inspection. |
| Public API CIDR allowlist | Separately restricts which source IPs can reach the public Kubernetes API endpoint. |

## IAM building blocks

| Item | Purpose |
| --- | --- |
| IAM role | Supplies temporary AWS permissions to a trusted identity or service. |
| Trust policy / `assume_role_policy` | Defines who may assume a role. |
| Permission policy | Defines which AWS operations a role session may perform. |
| Policy attachment | Connects an IAM permission policy to an IAM role. |
| `Principal` | Identifies the trusted service or identity in a trust policy. |
| `Effect = "Allow"` | Allows the actions covered by a matching statement, subject to other applicable policy controls. |
| `sts:AssumeRole` | Allows an eligible caller to obtain a temporary role session. |
| `sts:TagSession` | Allows session tags; Pod Identity uses these to carry workload identity information. |
| Policy `Version = "2012-10-17"` | Selects IAM's policy-language version, not the resource creation date. |
| `policy_arn` | Identifies the policy being attached or associated. |
| `role_arn` | Identifies the IAM role a resource should use. |

## Our identities, roles, and policies

| Item | Purpose |
| --- | --- |
| Existing `AuthentikAdmin` role | Is the human administrator identity obtained through Authentik; we did not create it. |
| `authentik` profile | Provides the CLI login configuration for the federated session. |
| `authentik-tf` profile | Makes that authentication available to our Terraform AWS provider. |
| Cluster IAM role | Gives the EKS service AWS permissions for operating the cluster. |
| Cluster trust: `eks.amazonaws.com` | Allows EKS to assume the cluster role. |
| `AmazonEKSClusterPolicy` | Supplies the cluster role's AWS management permissions. |
| Node IAM role | Gives EC2 workers AWS permissions for node duties. |
| Node trust: `ec2.amazonaws.com` | Allows EC2 instances to assume the node role. |
| `AmazonEKSWorkerNodePolicy` | Supplies node discovery permissions and supports Pod Identity credential retrieval. |
| `AmazonEC2ContainerRegistryPullOnly` | Allows private ECR image downloads, subject to repository access controls. |
| VPC CNI pod role | Gives the networking add-on its own permissions for network interfaces and pod IPs. |
| Pod trust: `pods.eks.amazonaws.com` | Allows EKS Pod Identity to assume the workload role. |
| `AmazonEKS_CNI_Policy` | Supplies VPC CNI's IPv4 networking permissions. |

The CNI role **is a pod role**: the general term describes roles used by workloads, and this particular role serves the networking pods. Our administrator role serves the human operator; the cluster, node, and CNI roles serve infrastructure.

## EKS control plane and endpoints

| Item | Purpose |
| --- | --- |
| EKS cluster | Creates the AWS-managed Kubernetes control plane. |
| Cluster `name` | Names our cluster `eks-lab`. |
| Cluster `version` | Selects Kubernetes 1.37. |
| Cluster `role_arn` | Assigns the cluster IAM role to EKS. |
| Cluster `subnet_ids` | Selects private subnets for EKS's network interfaces in our VPC. |
| `endpoint_private_access = true` | Enables private Kubernetes API access from within the VPC or suitably connected networks. |
| `endpoint_public_access = true` | Enables a public API endpoint for approved external clients. |
| `public_access_cidrs` | Restricts public API access to selected source IP ranges. |
| `admin_cidr` | Supplies the allowed administrator source range through a Terraform input. |
| `/32` | Represents exactly one IPv4 address. |
| `bootstrap_self_managed_addons = false` | Prevents default self-managed core add-ons because we explicitly install managed add-ons. |
| `authentication_mode = "API"` | Configures identity access through EKS access entries. |
| `bootstrap_cluster_creator_admin_permissions = false` | Disables automatically granting Kubernetes administrator access to the cluster creator. |

EKS places network interfaces in our subnets; the control plane itself runs in AWS-managed infrastructure. The management API endpoint is separate from an application's public URL or load balancer.

## Kubernetes administrator access

| Item | Purpose |
| --- | --- |
| EKS access entry | Registers the existing AuthentikAdmin IAM role as a cluster identity. |
| `principal_arn` | Identifies the permanent IAM role receiving Kubernetes access. |
| Access-entry `type = "STANDARD"` | Defines an ordinary entry, used here for the human administrator role. |
| Access-policy association | Connects the identity to an EKS Kubernetes access policy. |
| `AmazonEKSClusterAdminPolicy` | Grants full Kubernetes administrator permissions for the selected scope. |
| `access_scope.type = "cluster"` | Applies the permissions across the whole cluster. |

An EKS access policy controls Kubernetes permissions; an IAM permission policy controls AWS API permissions. Allowing a network source IP does not grant either set of permissions.

## Managed node group

| Item | Purpose |
| --- | --- |
| Managed node group | Supplies EC2 workers whose provisioning and replacement EKS manages. |
| `cluster_name` | Connects the node group to our EKS cluster. |
| `node_group_name` | Names the group `eks-lab-workers`. |
| `node_role_arn` | Assigns the worker IAM role. |
| Node-group `subnet_ids` | Selects private subnets as possible worker locations. |
| Node-group `version` | Matches the cluster's Kubernetes version. |
| `ami_type` | Selects the EKS-optimized Amazon Linux 2023 x86 image family. |
| `instance_types` | Selects t3.small: 2 vCPUs and 2 GiB RAM per node. |
| `capacity_type = "ON_DEMAND"` | Uses regular EC2 capacity rather than Spot capacity. |
| `disk_size = 20` | Gives each worker a 20 GiB root disk. |
| `desired_size = 2` | Requests two workers initially. |
| `min_size = 1` | Sets minimum permitted group capacity. |
| `max_size = 2` | Sets maximum permitted group capacity. |
| `max_unavailable = 1` | Limits unavailable workers during managed updates to one. |
| Node autoscaler | Is not installed; scaling bounds alone do not react to pending pods. |

## Add-ons and workload identity

| Item | Purpose |
| --- | --- |
| EKS managed add-on | Installs supporting cluster software through the EKS add-on API. |
| `addon_name` | Selects the software to install. |
| `addon_version` | Pins a version reported by AWS as compatible with Kubernetes 1.37. |
| VPC CNI / `vpc-cni` | Assigns VPC addresses to pods and configures pod networking. |
| CoreDNS / `coredns` | Resolves internal Kubernetes service names. |
| `kube-proxy` | Configures node networking rules for Kubernetes Service traffic. |
| Pod Identity Agent | Supplies temporary credentials to pods with matching Pod Identity associations. |
| Pod Identity association | Maps a namespace/service account to an IAM role. |
| Namespace `kube-system` | Contains system components, including our networking add-on. |
| Service account `aws-node` | Is the Kubernetes identity used by VPC CNI pods. |
| Association `role_arn` | Selects the CNI IAM role those pods receive. |
| CNI dependency | Requires its Pod Identity association before Terraform creates the CNI add-on. |
| CoreDNS dependency | Waits for node-group creation before installing CoreDNS. |

```text
CNI pod → kube-system/aws-node → Pod Identity Agent → CNI IAM role → AWS networking APIs
```

Resource ordering alone does not prove runtime health. Our required evidence remains successful apply, Ready nodes, healthy add-ons, DNS resolution, a Ready test workload, and verified cleanup.

## Source references

- [Terraform S3 backend and native locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [EKS cluster IAM role](https://docs.aws.amazon.com/eks/latest/userguide/cluster-iam-role.html)
- [EKS node IAM role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)
- [EKS networking add-ons](https://docs.aws.amazon.com/eks/latest/userguide/workloads-add-ons-available-eks.html)
- [Full lab Terraform implementation](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/02-terraform-implementation.md)
