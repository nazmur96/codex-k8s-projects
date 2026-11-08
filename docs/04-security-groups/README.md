# Lab 04 — Restrictive AWS security groups

**Master catalog #18: Build restrictive AWS security groups and test traffic.
Build and proof session: November 8, 2026.**

This lab proves that security groups, not subnets or routes, decide which
machine may talk to which. Three instances share one private subnet and one
route table. Only the security group attached to each one differs, and that
alone decides who gets through.

| Catalog stage | Scope | Status |
| --- | --- | --- |
| Learn | Stateful SG behaviour, ingress/egress rules, dependency paths | Done — see concepts |
| Build | Separate ALB, application and database security groups | Done — 5 SGs, 12 rules |
| Prove | Only ALB → app and app → DB allowed; invalid paths fail | Done — 7-path matrix below |
| Break | Remove the DB's only app rule and watch app → DB fail | Done |
| Cleanup | Destroy and verify removal | See the cleanup section |

## Read in order

1. [Concepts](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/04-security-groups/01-concepts.md):
   default deny, two rules per connection, the probe, timeouts, and access options.
2. [Build, with complete files](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/04-security-groups/02-build.md).
3. [Proofs, break drill, cost and cleanup](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/04-security-groups/03-proof-and-cleanup.md).

Implementation: [labs/04-security-groups](https://github.com/nazmur96/codex-k8s-projects/tree/main/labs/04-security-groups).

## Topology (now removed)

```text
VPC 10.50.0.0/16 — eu-central-1
├── public_a   10.50.0.0/24   eu-central-1a  ALB
├── public_b   10.50.1.0/24   eu-central-1b  ALB (AWS requires two AZs)
└── private_a  10.50.10.0/24  eu-central-1a  app, db, probe, Instance Connect Endpoint
                                             local route only — no internet, no NAT

Internet ──80──▶ [ALB] ──8080──▶ [app] ──5432──▶ [db]
                                  [probe] ──✗──▶ [db], [app]
You ──AWS──▶ [EC2 Instance Connect Endpoint] ──22──▶ app / db / probe
```

| SG | Inbound | Outbound |
| --- | --- | --- |
| `alb` | 80 from `0.0.0.0/0` | 8080 to `app` SG |
| `app` | 8080 from `alb` SG; 22 from `eice` SG | 5432 to `db` SG |
| `db` | 5432 from `app` SG; 22 from `eice` SG | none |
| `probe` | 22 from `eice` SG | all TCP to `10.50.0.0/16` |
| `eice` | none | 22 to `app`, `db`, `probe` SGs |

## Results

| # | Path | Expected | Result | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Internet → ALB:80 | allow | ✅ | `HTTP/1.1 200 OK`, Python server header (agent-captured) |
| 2 | ALB → app:8080 | allow | ✅ | target `healthy` (agent-captured) + the 200 above |
| 3 | app → db:5432 | allow | ✅ | `hello from db` (learner-reported) |
| 4 | endpoint → app, probe:22 | allow | ✅ | SSH logins succeeded (learner-reported) |
| 5 | probe → db:5432 | deny | ✅ | `exit=28`, silent drop (learner-reported) |
| 6 | probe → app:8080 | deny | ✅ | `exit=28` (learner-reported) |
| 7 | ALB → db:5432 | deny | ✅ | live db SG rules list only `app` and `eice` (agent-captured, configuration evidence) |
| B | app → db after removing `db_from_app` | deny | ✅ | `exit=28` (learner-reported) |

The restore-and-re-prove step after the break was skipped for time. Path 3
had already been proven before the break. The rule is restored in the
committed code.

## Decisions

| Decision | Why |
| --- | --- |
| New, separate lab instead of extending lab 03 | Matches the catalog's "independent, smallest setup" design; lab 03 is unfinished |
| All three instances in one subnet | Removes routing as a possible explanation, so a block can only come from an SG |
| One private subnet, not one per AZ | One copy of each instance; a second subnet would stay empty and add no availability |
| Instance Connect Endpoint, not SSM or a bastion | Free; instances need no internet, NAT or IAM role |
| Python `http.server` on 5432 instead of PostgreSQL | The test is TCP reachability; no package install needed |
| Local Terraform state | Single-user lab; `.gitignore` excludes it |
| Changes through Terraform only | The break was a code change and a reviewed plan, not a console edit |
