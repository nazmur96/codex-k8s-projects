# Kubernetes Projects

Hands-on Kubernetes projects with Terraform, clear explanations, verification evidence, and cleanup.

## Project 01: EKS with managed node groups

Build a minimal Amazon EKS cluster using explicit Terraform resources: a two-AZ VPC, private worker nodes, IAM roles, managed add-ons, and restricted administrator access.

**Current checkpoint — November 5, 2026:** build and verification completed after recovering a node-group launch failure. Two nodes Ready, system pods healthy, DNS resolved, and test workload Ready. Destroy approved; final cleanup result and verification pending.

| Guide | Contents |
| --- | --- |
| [01 — Development environment](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/01-development-environment.md) | Full mise/devcontainer files, Vim steps, Docker/DevPod/SSH, Cursor troubleshooting, AWS mount, Authentik login, host-tool cleanup |
| [02 — Terraform implementation](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/02-terraform-implementation.md) | Full Terraform file contents and explanations: networking, IAM, EKS, access, nodes, and add-ons |
| [03 — Decisions and preflight](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/03-decisions-and-preflight.md) | Budget, cost estimate, version queries, IP lookup troubleshooting, production tradeoffs, state and modules |
| [04 — Deployment and evidence](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/04-deployment-and-evidence.md) | Plan/apply record, current status, pending proof, and cleanup requirements |
| [05 — Terraform quick reference](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/05-terraform-reference.md) | Every component and setting explained in one-line tables: VPC, routing, SG/NACL, IAM, endpoints, workers, add-ons, and state |
| [06 — Node launch failure and recovery](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/01-eks-managed-node-groups/06-node-launch-failure.md) | Free Tier restriction, partial deployment, eligible instance lookup, and reviewed recovery |

## Repository layout

```text
.devcontainer/devcontainer.json   Development container and local AWS mount
mise.toml                        Pinned project tools
terraform/                       Runnable root module and provider lock file
kubernetes/test-app.yaml         Verified NGINX test Deployment
docs/01-eks-managed-node-groups/  Step-by-step project guides
```

Terraform remains in its existing directory throughout deployment and cleanup. Future projects can have their own code and guide directories. No live working directory or state was moved for this documentation change.

## Progress

- [x] Prepare and verify the Docker devcontainer and pinned tools.
- [x] Verify Authentik-backed CLI and Terraform profiles.
- [x] Confirm account-wide budget alerts and review cost estimate.
- [x] Write Terraform and validate configuration.
- [x] Review a saved plan and obtain creation approval.
- [x] Complete infrastructure creation after recovery with eligible t3.small workers.
- [x] Prove nodes Ready, core add-on pods healthy, and DNS functional.
- [x] Deploy and verify a test workload.
- [ ] Destroy lab infrastructure with approval and verify cleanup.

**Cost:** allow approximately $0.25–$0.30/hour before taxes and usage-based extras for the initial t3.medium configuration; the final t3.small workers reduce compute cost. The existing $40/month account-wide budget is an alert, not a spending cap. Keep state private, preserve it for cleanup, and destroy the lab after testing. See guide 03 for assumptions and pricing references.

Documentation is updated as work is completed. Article publishing is a separate, later action.
