# Proofs, break drill, cost and cleanup

Evidence labels: **agent-captured** means the agent ran the command and saw the
output. **Learner-reported** means the learner ran it and reported the result
without pasting raw output.

## Before creation

| Check | Result (November 8, 2026) |
| --- | --- |
| Identity | `assumed-role/AuthentikAdmin`, account `750702271569` (agent-captured) |
| Budget | `podinfo-monthly`, account-wide (no filters), USD 40 limit, USD 0.0 actual, USD 0.072 forecast (agent-captured). It sends alerts; it is not a spending cap. |
| `t3.micro` | Free Tier eligible on this account; offered in `eu-central-1a` (agent-captured) |
| Saved plan | 36 to add, 0 to change, 0 to destroy (agent-reviewed) |

### Cost estimate (AWS Pricing API, Frankfurt, on-demand)

| Item | Price | Per hour |
| --- | --- | --- |
| 3 × t3.micro | USD 0.012/h each | 0.036 |
| ALB | USD 0.027/h + USD 0.008 per LCU-hour (tiny test traffic) | ~0.03 |
| 2 public IPv4 on the ALB | USD 0.005/h each | 0.010 |
| 3 × ~8 GB gp3 | USD 0.0952 per GB-month | ~0.003 |
| Instance Connect Endpoint, IGW, VPC, SGs | free | 0 |
| **Total** | | **≈ 0.08–0.09** |

The ALB is billed for each started hour. Free Tier may cover part of this, but
eligibility is not a zero-cost guarantee. The resources ran for under an hour:
the instances booted around 15:13 UTC, and the destroy finished between 15:40
and 15:55 UTC.

## Proof 1 — internet → ALB → app

**Container terminal, lab folder:**

```sh
curl -i "$(mise exec -- terraform output -raw alb_url)"
```

Agent-captured:

```text
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: 15
Server: SimpleHTTP/0.6 Python/3.9.25
```

The `Server` header shows the reply came from the Python listener on the
private app instance. Target health was also agent-captured:

```text
i-081cc3495fa38aecc  8080  healthy
```

The health check needs `alb_to_app` and `app_from_alb`, so a healthy target is
itself evidence for path 2.

## Proof 2 — SSH into the app, then app → db

**Container terminal:**

```sh
mise exec -- aws ec2-instance-connect ssh \
  --instance-id i-081cc3495fa38aecc \
  --connection-type eice \
  --os-user ec2-user \
  --profile authentik-tf --region eu-central-1
```

The CLI pushes a temporary SSH key (valid for 60 seconds), opens a tunnel
through the endpoint, and starts `ssh`. Accept the host key with `yes`.

**Inside the app:**

```sh
curl -s -m 5 http://10.50.10.138:5432
```

Learner-reported: login succeeded (path 4), and the reply was
`hello from db` (path 3).

## Proof 3 — the probe is refused

**Container terminal:** the same `ssh` command with
`--instance-id i-00ce573b2c2eb2094`.

**Inside the probe:**

```sh
curl -s -m 5 http://10.50.10.138:5432 ; echo "exit=$?"
curl -s -m 5 http://10.50.10.179:8080 ; echo "exit=$?"
```

Learner-reported: both hung for 5 seconds and returned `exit=28` (timed out).
The probe has the same subnet and routes as the app, and its own SG allows
any TCP inside the VPC. The db and app SGs dropped the packets silently.

## Proof 4 — ALB → db is not permitted (configuration evidence)

An ALB cannot be made to send traffic to an arbitrary port, so this path was
proven from the live rules rather than live traffic. Agent-captured:

```text
db SG sg-0439a67237cba41a3:
  inbound  5432  from sg-01cd1754db64a936b (app)   "App to database"
  inbound  22    from sg-09561c98c3eb4752e (eice)  "SSH from connect endpoint"
  outbound (none)
```

The ALB SG is not listed, and the ALB's only outbound rule targets the app on
8080. ALB → db is blocked at both ends.

```sh
mise exec -- aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=<db-sg-id> \
  --profile authentik-tf --region eu-central-1 --no-cli-pager \
  --query 'SecurityGroupRules[].{Egress:IsEgress,Port:FromPort,From:ReferencedGroupInfo.GroupId,Desc:Description}' \
  --output table
```

## Break drill — remove `db_from_app`

The `db_from_app` block in `security-group-rules.tf` was commented out.
The change went through Terraform, not the console.

```sh
mise exec -- terraform plan -out=break.tfplan
```

Agent-reviewed:

```text
# aws_vpc_security_group_ingress_rule.db_from_app will be destroyed
# (because aws_vpc_security_group_ingress_rule.db_from_app is not in configuration)
Plan: 0 to add, 0 to change, 1 to destroy.
```

After learner approval: `mise exec -- terraform apply break.tfplan`.

Learner-reported: from the app, `curl -s -m 5 http://10.50.10.138:5432`
returned `exit=28`. The app still had `app_to_db`, so traffic could leave; the
db no longer accepted it. One connection needs both rules.

**Not done:** restoring the rule through a fresh apply and re-proving path 3,
plus a final no-change plan. Both were skipped for time. Path 3 had passed
before the break. The block is uncommented again in the committed code, so a
fresh apply recreates all 36 resources, including `db_from_app`.

## Cleanup

After learner approval, from this lab folder only:

```sh
mise exec -- terraform destroy
```

Only answer `yes` if the summary reads `Plan: 0 to add, 0 to change, 35 to destroy.`
(36 minus the rule removed in the break drill). The learner confirmed
completion. Agent-captured verification at about 15:55 UTC:

| Check | Result |
| --- | --- |
| `terraform state list` | empty |
| Instances tagged `Project=security-groups-lab` | all three `terminated` (stay listed for about an hour; no charge) |
| VPC `10.50.0.0/16` or tagged | none |
| Security groups `seclab-*` | none |
| Instance Connect Endpoints not `delete-complete` | none |
| ALB `seclab-dev`, target group `seclab-app` | none |
| Unattached EBS volumes in the region | none |
| Elastic IPs in the region | none |
| Budget after the lab | USD 0.0 actual, 0.072 forecast (billing lags; charges can still appear) |

The local state file and saved plans (`lab04.tfplan`, `break.tfplan`) remain
in the lab folder and are excluded from Git. The saved plans are stale; never
apply them.

## Git hygiene

Committed: `.tf` files, `.terraform.lock.hcl`, and these guides. Excluded by
`.gitignore`: `.terraform/`, state and backups, lock metadata, saved plans,
tfvars and AWS configuration. No credentials, login URLs or real admin IPs
appear in the docs. The private IPs and resource IDs recorded here belonged to
deleted resources.
