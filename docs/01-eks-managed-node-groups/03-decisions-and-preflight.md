# Decisions and preflight checks

## Budget and cost awareness

In the Authentik-backed AWS Console, opened Billing and Cost Management → Budgets → existing podinfo budget. The learner confirmed $40/month, alert thresholds and email recipient configured, and no filters. Therefore it covers the entire account, including both projects. Exact thresholds were not recorded. Alerts notify; they do not cap spending. No new budget was created.

**Historical first-plan estimate:** the pre-apply allowance was approximately $0.25–$0.30/hour before tax and usage-based extras: $0.10/hour standard-support EKS control plane, approximately $0.096/hour for two Frankfurt t3.medium nodes, approximately $0.05–$0.07/hour NAT, $0.005/hour public IPv4, and under $0.01/hour for 40 GiB total root storage. This is an estimate, not a billing guarantee. Roughly $1–$1.20 for four hours or $183–$219 for 730 hours, before extras. NAT processing, cross-AZ transfer, internet egress, and possible burst CPU charges are additional. Creation/deletion time also contributes to usage.

Sources: [EKS](https://aws.amazon.com/eks/pricing/), [VPC/NAT/IPv4](https://aws.amazon.com/vpc/pricing/), [EC2](https://aws.amazon.com/ec2/pricing/on-demand/), [Frankfurt instance estimate](https://www.doit.com/compute/compute/aws/eu-central-1/t3.medium), [EBS](https://aws.amazon.com/ebs/pricing/). Recheck regional prices before future runs.

The learner explicitly approved this creation and intends to test quickly, then destroy. Every future apply/destroy still requires the applicable explicit approval; this document is not blanket permission.

## Kubernetes version selection

Ran inside the container:

```sh
mise exec -- aws eks describe-cluster-versions \
  --profile authentik-tf \
  --region eu-central-1 \
  --query 'clusterVersions[].[clusterVersion,versionStatus,endOfStandardSupportDate]' \
  --output table
```

The first attempt hit expired credentials; repeating remote login fixed it. AWS returned this table, as reported by the learner:

| Version | Status | Standard support ends |
| --- | --- | --- |
| 1.37 | STANDARD_SUPPORT | 2027-12-01 |
| 1.36 | STANDARD_SUPPORT | 2027-08-02 |
| 1.35 | STANDARD_SUPPORT | 2027-03-27 |
| 1.34 | STANDARD_SUPPORT | 2026-12-02 |
| 1.33 | EXTENDED_SUPPORT | 2026-07-29 |
| 1.32 | EXTENDED_SUPPORT | 2026-03-23 |
| 1.31 | EXTENDED_SUPPORT | 2025-11-26 |

Selected 1.37, under standard support and matching kubectl's minor version. Extended support has higher control-plane charges. These are recorded observations, not a promise of availability on a future date.

## Find the API allowlist IP

Host attempts failed:

```sh
curl -4 https://checkip.amazonaws.com
curl -4 https://api.ipify.org
```

The browser lookup failed too. The host reported connection resets; another lookup to icanhazip.com reported a TLS handshake failure. No definitive cause was established, and no network setting was changed.

A read-only Tailscale status check showed it was running and online, with no active exit node. The host Cloudflare trace and container AWS check-IP lookup then returned the same outbound public IPv4 address:

```sh
# Host alternative used during investigation:
curl -4 https://www.cloudflare.com/cdn-cgi/trace

# Container: learner successfully ran this:
curl -4 https://checkip.amazonaws.com
```

The actual address remains in ignored local variables, not this guide. The lookup reports the public egress IP, not the container's internal address. Docker and host traffic shared that IP in our observed setup. Moving the container to a remote host or using a VPN exit node can change it. Ordinary Tailscale membership alone does not connect this container to the AWS VPC.

Production options include a restricted public API endpoint allowing stable office/VPN egress addresses, or a private-only endpoint reachable over an approved VPC network connection. Each operator still authenticates individually. The Kubernetes management API is separate from an application's public load balancer/URL.

## Retrieve the administrator role ARN

```sh
mise exec -- aws iam get-role \
  --role-name AuthentikAdmin \
  --profile authentik-tf \
  --query 'Role.Arn' \
  --output text
```

Returned arn:aws:iam::750702271569:role/AuthentikAdmin. Access entries use this permanent IAM role ARN, rather than the temporary STS assumed-role session ARN.

## Select compatible add-on versions

```sh
mise exec -- aws eks describe-addon-versions \
  --profile authentik-tf \
  --region eu-central-1 \
  --kubernetes-version 1.37 \
  --query 'addons[?addonName==`vpc-cni` || addonName==`coredns` || addonName==`kube-proxy` || addonName==`eks-pod-identity-agent`].{Name:addonName,DefaultVersions:addonVersions[?compatibilities[?defaultVersion==`true`]].addonVersion}' \
  --output json
```

| Add-on | Returned default compatible version |
| --- | --- |
| eks-pod-identity-agent | v1.4.1-eksbuild.3 |
| kube-proxy | v1.37.0-eksbuild.32 |
| coredns | v1.14.7-eksbuild.22 |
| vpc-cni | v1.22.4-eksbuild.10 |

These versions are pinned in addons.tf. Runtime health remains to be proven.

## Local state versus S3 remote state

This short single-operator lab uses the default local backend. terraform/terraform.tfstate is in the host-mounted project directory and persists outside the container. It and its backups/lock metadata are ignored by Git. Preserve the state until cleanup is verified; closing a terminal or removing a container does not destroy AWS infrastructure.

For team use, remote state normally comes before deployment. Terraform's S3 backend supports native locking through use_lockfile = true; it is opt-in, not the default. DynamoDB locking is deprecated. An existing bucket, restricted access, encryption, and versioning are needed for a sound setup. Backend credentials are configured independently of the AWS provider. We have not created or configured a remote backend here. [HashiCorp S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## File structure and future projects

All .tf files in terraform/ form one root module. Names such as network.tf and modules.tf organize human reading; they do not determine execution order. References/dependencies determine ordering. Child modules help reuse and shared standards; extra files alone do not make a production platform.

The November 4 downloaded master catalog, deduplicated-devops-projects.md, explicitly separates these learning objectives:

| Catalog project | Focus |
| --- | --- |
| 16 | Terraform remote state, reusable networking module, locking, tags, environments |
| 17 | Three-tier production-style VPC |
| 18 | Restrictive security groups and traffic tests |
| 21 | Terraform module tests and drift detection |
| 22 | Automated cost controls |
| 23 | This EKS/node-group/core-add-on lab |

The Kubernetes-only extract deliberately omits foundational projects 16–22. We retain this lab's explicit resources and local state, leaving remote-state/module exercises for a separate project. The broader DevSecOps workflow remains a reference; this exercise does not claim to complete a full production platform.

## Update after the first apply

AWS rejected t3.medium under the account’s Free Tier restriction. We switched to two eligible t3.small workers, each with 2 vCPUs and 2 GiB RAM. The recovery apply and all three required functional checks succeeded. The original estimate above describes the initial configuration; the smaller nodes reduce compute cost. It is not an actual measured bill. See guide 06 for diagnosis, plan, and recovery details.
