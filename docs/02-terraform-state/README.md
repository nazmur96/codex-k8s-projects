# Lab 02 — Terraform remote state, modules and locks

**Master catalog project #16. Completed build and proof session: November 6, 2026. Cleanup pending.**

This lab teaches how to share Terraform's resource record safely and reuse the same network code. You create a small AWS network, store its state in S3, and deliberately make two applies compete for the same state lock.

| Catalog requirement | What we did |
| --- | --- |
| Learn S3 backend and locking | S3 state with native lock files |
| Learn modules, tags and environments | A networking module called by a dev root, with consistent tags |
| Build separate networking module and remote state | One VPC and two subnets; separate backend bootstrap root |
| Prove competing applies cannot write together | Terminal B failed to acquire terminal A's active apply lock |
| Prove clean plan after apply | Captured no-change plan and exit code 0; final repeat learner-confirmed |

Only dev was deployed. Staging is explained as an extension, not claimed as completed. The test demonstrates locking for cooperating Terraform processes using the same state; it is not a guarantee against manual AWS changes or bypassing locks.

## Read in this order

Prefer learning through a story? Start with [a conversation between folders](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/04-folder-conversation.md), which follows the storage manager, project manager and network engineer through all ten chapters.

1. [Understand the ideas](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/01-concepts.md).
2. [Build it step by step, with complete files](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/02-build.md).
3. [Run the proofs, troubleshoot and clean up](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/02-terraform-state/03-proof-and-cleanup.md).

## What exists

```text
AWS account 750702271569 / eu-central-1
├── S3 backend bucket: nazmur96-tfstate-750702271569-euc1
│   ├── Versioning, encryption and public-access blocks
│   └── project-16/dev/terraform.tfstate
└── Dev network
    ├── VPC: 10.30.0.0/16
    ├── private_a: 10.30.10.0/24, eu-central-1a
    └── private_b: 10.30.11.0/24, eu-central-1b
```

The lock object uses the state key plus `.tflock` and normally exists only while an operation holds the lock. There are no EC2 instances, EKS clusters, internet gateways or NAT gateways in this lab. AWS also creates the VPC's default networking objects automatically.

## Current checkpoint

The learner ran all project commands. Source files and provider lock files were inspected for documentation. Bootstrap apply output records 4 added; network apply output records 3 added. Versioning was learner-confirmed Enabled. A full lock-contention error was supplied. Final tag apply and final clean-plan repeat were learner-confirmed without raw output. No project #16 destroy has been approved or recorded.

The account-wide `podinfo-monthly` budget was checked before bootstrap creation: USD 40 limit, USD 0 actual, USD 0.078 forecast, no filters. This is a dated reading, not current billing evidence or a spending cap. No Podinfo resources were changed by this lab.

S3 storage, object versions and requests can incur charges. Preserve the backend and bootstrap state until cleanup is deliberately completed.
