# Kubernetes Projects

Hands-on Kubernetes projects with Terraform, clear explanations, verification evidence, and cleanup.

## Project 01: EKS with managed node groups

Build a minimal Amazon EKS cluster using explicit Terraform resources: a two-AZ VPC, private worker nodes, IAM roles, managed add-ons, and restricted administrator access.

**Checkpoint — November 6, 2026:** build and verification completed. Follow-up cleanup checks found empty Terraform state, no eks-lab cluster, and no VPC or Elastic IP matching the lab names. A separate orphaned-volume scan was not captured. See the lab 02 proof guide for the supplied cleanup evidence.

| Guide | Contents |
| --- | --- |
| [01 — Development environment](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/01-development-environment.md) | Full mise/devcontainer files, Vim steps, Docker/DevPod/SSH, Cursor troubleshooting, AWS mount, Authentik login, host-tool cleanup |
| [02 — Terraform implementation](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/02-terraform-implementation.md) | Full Terraform file contents and explanations: networking, IAM, EKS, access, nodes, and add-ons |
| [03 — Decisions and preflight](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/03-decisions-and-preflight.md) | Budget, cost estimate, version queries, IP lookup troubleshooting, production tradeoffs, state and modules |
| [04 — Deployment and evidence](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/04-deployment-and-evidence.md) | Plan/apply record, current status, pending proof, and cleanup requirements |
| [05 — Terraform quick reference](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/05-terraform-reference.md) | Every component and setting explained in one-line tables: VPC, routing, SG/NACL, IAM, endpoints, workers, add-ons, and state |
| [06 — Node launch failure and recovery](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/06-node-launch-failure.md) | Free Tier restriction, partial deployment, eligible instance lookup, and reviewed recovery |

## Lab 02: Terraform remote state, modules and locks — catalog #16

Build a reusable VPC/subnet module, store dev state in S3, and prove two applies cannot hold the same state lock. Build and required proofs completed November 6, 2026; **lab 02 cleanup remains pending**.

[Start the beginner guide](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/README.md) · [Concepts](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/01-concepts.md) · [Complete files and commands](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/02-build.md) · [Proofs, troubleshooting and cleanup](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/03-proof-and-cleanup.md)

[Read the folder conversation](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/04-folder-conversation.md) — follow bootstrap, dev and the network module as three employees exchanging inputs and outputs.

## Repository layout

```text
.devcontainer/                    Shared Docker development environment
mise.toml                         Pinned tools inside the container
terraform/                        Lab 01 EKS root (existing location)
kubernetes/                       Lab 01 test workload
labs/02-terraform-state/bootstrap/ Backend bucket root (local state)
labs/02-terraform-state/modules/   Reusable networking module
labs/02-terraform-state/environments/dev/ Dev root (S3 state)
docs/01-eks-managed-node-groups/   Lab 01 guides
docs/02-terraform-state/           Lab 02 guides
```

No existing live root or state was relocated. Each lab retains its own cleanup scope.

## Lab 01 progress

- [x] Prepare and verify the Docker devcontainer and pinned tools.
- [x] Verify Authentik-backed CLI and Terraform profiles.
- [x] Confirm account-wide budget alerts and review cost estimate.
- [x] Write Terraform and validate configuration.
- [x] Review a saved plan and obtain creation approval.
- [x] Complete infrastructure creation after recovery with eligible t3.small workers.
- [x] Prove nodes Ready, core add-on pods healthy, and DNS functional.
- [x] Deploy and verify a test workload.
- [x] Confirm empty state and absence of the named EKS cluster, VPC and NAT Elastic IP (November 6 learner-supplied checks).

**Cost:** allow approximately $0.25–$0.30/hour before taxes and usage-based extras for the initial t3.medium configuration; the final t3.small workers reduce compute cost. The existing $40/month account-wide budget is an alert, not a spending cap. Keep state private, preserve it for cleanup, and destroy the lab after testing. See guide 03 for assumptions and pricing references.

Documentation is updated as work is completed. Article publishing is a separate, later action.
