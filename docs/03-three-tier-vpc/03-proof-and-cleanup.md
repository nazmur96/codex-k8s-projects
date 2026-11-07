# Proof and cleanup plan — not yet executed

**No live proof has run for catalog #17.** This checklist describes acceptance
criteria to refine when the remaining workload code is complete. A valid
configuration or successful apply alone will not complete the lab.

## Before creation

- Confirm account `750702271569` and role `AuthentikAdmin` using current
  short-lived credentials.
- Recheck the existing account-wide $40 `podinfo-monthly` budget and current
  spend; earlier lab readings are dated evidence, not today's cost check.
- Check current Frankfurt prices for NAT hours/data, NAT public IPv4, ALB
  hours/LCUs and managed public IPv4, EC2, EBS, and possible cross-AZ transfer.
  S3 gateway endpoints have no additional endpoint charge; other service
  requests/storage can still cost money. Budget alerts do not cap spending.
- Confirm instance eligibility, architecture, AZ offerings and resource quotas.
- Decide state storage and retain it privately throughout cleanup.
- Review a fresh Terraform plan for only this lab. Ask before every apply,
  destroy and billed-resource creation. The learner runs approved commands
  unless they explicitly delegate execution.

## Proof matrix

| Requirement | Required evidence | Current result |
| --- | --- | --- |
| Two-AZ three-tier layout | Six subnet CIDRs/AZs; correct table associations | Configuration only |
| Public ALB reaches private APIs | Healthy targets; HTTP `/` and `/health`; no public IPs on APIs | Pending |
| API reaches intended DB | `/db` succeeds; records a TCP handshake, not SQL authentication | Pending |
| DB stays private | No DB public IP; isolated routes; SG accepts only API:5432; explicit unauthorized-source connection fails | Pending |
| ALB cannot directly reach DB | Destination SG excludes ALB; controlled negative traffic test design | Pending |
| API outbound HTTPS | Approved HTTPS request succeeds through NAT | Pending |
| S3 endpoint route | Both API tables contain S3 prefix-list route to expected endpoint; verify path with a scoped test | Pending |
| NACL understanding | Scoped stateless deny/restore drill, including return-path reasoning | Pending |
| Deliberate break and recovery | Temporarily block API-to-DB rule through reviewed Terraform, observe `/db` fail, restore and re-prove | Pending |
| Final convergence | Fresh Terraform plan reports no changes | Pending |

A laptop's failed attempt to route to an RFC1918 DB address alone is not proof
of correct security-group enforcement. Combine configuration evidence with
an unauthorized source that has a valid route to the destination. Design that
probe's permissions and execution path before claiming success. Do not create
an unreviewed extra billed probe instance.

Removing API-to-DB connectivity should make `/db` return 503 while the simple
`/health` remains 200. That health check measures process availability, not
database readiness. Each approved recovery apply needs a fresh reviewed plan;
do not reuse stale saved plans or change unrelated projects.

When running a future safe `terraform plan -detailed-exitcode`, exit 0 means
no diff, 2 means changes and 1 means error. Never invent output; distinguish
captured command evidence from a learner-reported result.

## Cleanup after the eventual deployment

No project #17 resources were created in this teaching session. No lab-specific
destroy was needed at this checkpoint; this is not an account-wide cost audit.

After proof, the learner should review a fresh destroy plan **from this lab's
root** and obtain explicit destroy approval. Only then run the approved destroy.
Preserve state after partial failures and inspect remaining objects instead of
deleting state records. Do not use lab 01/02 roots for lab 03 cleanup.

Verify empty lab state and AWS absence of its EC2 instances, ALB/target group,
NAT, Elastic IP, endpoint and VPC. Check root volumes were removed and look for
orphaned EBS snapshots/volumes if any were introduced. Verify lab IAM resources
are removed too. Capture actual results before marking cleanup complete.

If a remote state bucket is introduced later, treat its lifecycle separately:
keep it through workload destruction, then explicitly decide retention versus
approved removal of current objects and all historical versions/delete markers.
Do not remove shared backends or the Authentik identity configuration.

## Git hygiene

Commit `.tf`, application/startup templates, documentation and provider lock
files. Exclude `.terraform/`, state/backups, lock metadata, saved plans, tfvars,
AWS config/caches, login URLs/codes, tokens and kubeconfig. Public examples must
not contain real administrator IP values or database credentials. Keep internal
Markdown links absolute GitHub URLs. Article syndication requires a separate
specific publishing request through syndicate.
