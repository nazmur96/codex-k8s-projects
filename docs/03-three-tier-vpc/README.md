# Lab 03 — Three-tier AWS VPC

**Master catalog #17: Build a 3-tier AWS VPC with public/private subnets.**

**Checkpoint — November 7, 2026: implementation in progress; not deployed.**
The network and ALB are declared, but EC2 workloads, their startup configuration,
target registrations and the state-backend decision remain unfinished. Do not
apply this partial configuration as if it were a working application.

| Catalog stage | Scope | Status |
| --- | --- | --- |
| Learn | CIDRs, route tables, internet/NAT gateways, security groups and NACLs | In progress |
| Build | Public ALB, private API and isolated database tiers across two AZs | Partially written |
| Prove | Internet reaches ALB; database stays private; API reaches dependencies | Not run |
| Cleanup | Destroy and verify removal after deployment | No deployment recorded for this lab |

## Read in order

1. [Design and concepts](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/03-three-tier-vpc/01-design-and-concepts.md).
2. [Build guide and checkpoint](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/03-three-tier-vpc/02-build-and-checkpoint.md).
3. [Complete checkpoint source](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/03-three-tier-vpc/04-checkpoint-source.md).
4. [Proof and cleanup plan](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/03-three-tier-vpc/03-proof-and-cleanup.md).

## Planned topology

```text
VPC 10.40.0.0/16 — eu-central-1
├── eu-central-1a
│   ├── public_a   10.40.0.0/24  — ALB + single zonal NAT gateway
│   ├── api_a      10.40.10.0/24 — planned API EC2
│   └── database_a 10.40.20.0/24 — planned database EC2
└── eu-central-1b
    ├── public_b   10.40.1.0/24  — same ALB spans both public subnets
    ├── api_b      10.40.11.0/24 — planned API EC2
    └── database_b 10.40.21.0/24 — subnet only; no database replica planned

Requests: Internet → ALB:80 → API:8080 → PostgreSQL:5432
API egress: regional S3 → gateway endpoint; other public HTTPS → NAT → IGW
Database: local VPC route only; no internet default route
```

Two-AZ subnets do not make every component highly available. One zonal NAT
creates an egress dependency on AZ A, and one planned database instance is a
single point of failure. This is a small networking lab, not a production HA
database platform. No EKS, Gateway API, Kubernetes Ingress or RDS is planned.

## Resume here

Continue with the learner writing one small step at a time. Next: API startup
configuration, then a concrete database bootstrap/management design that
preserves its isolated routing. Declare the EC2 instances and target-group
attachments after those decisions. Resolve state storage before applying.
Lab 02's backend bucket was deleted; do not assume it exists.

No project #17 apply, AWS resource creation or live proof is recorded. No new
account-wide resource audit is claimed. The earlier lab 02 cleanup record is
in its own guide. Documentation publishing to dev.to/LinkedIn is separate.
