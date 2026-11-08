# Concepts

## Security groups in one table

| Idea | Meaning in this lab |
| --- | --- |
| **Stateful** | If a connection is allowed in, its reply goes back automatically. Write rules only for the side that starts the connection. The db has no outbound rules: it only answers. |
| **Allow-only, default deny** | An SG has no deny rule type. It is a guest list: anything not listed is refused. The db never names the probe; the probe is refused because it is not on the list. |
| **SG references** | `referenced_security_group_id` means "any network interface with that SG attached". It does not mean "a subnet" or "an IP range". |
| **Attached to interfaces** | SGs apply to each network interface (instance, ALB node, endpoint), not to subnets. Two machines in one subnet can have completely different access. |
| **Terraform removes default egress** | AWS gives every new SG an allow-all outbound rule. Terraform deletes it, so every outbound path in this lab is written on purpose. |

## One connection needs two rules

When both ends have a restrictive SG, traffic needs permission to **leave** the
sender and permission to **arrive** at the receiver:

```text
[app] ── egress on app SG ──▶ ── ingress on db SG ──▶ [db]
      "app may SEND to db:5432"   "db may ACCEPT from app:5432"
```

Either rule missing means the connection fails. The break drill proved this:
the app kept `app_to_db`, lost `db_from_app`, and timed out.

| Path | Rule on the sender | Rule on the receiver |
| --- | --- | --- |
| Internet → ALB:80 | none — the internet has no SG | `alb_http_in` |
| ALB → app:8080 | `alb_to_app` | `app_from_alb` |
| app → db:5432 | `app_to_db` | `db_from_app` |
| endpoint → instance:22 | `eice_ssh_out[...]` | `ssh_from_eice[...]` |

The ALB health check uses path 2 too. A missing rule there shows up first as an
unhealthy target and a `502`/`503` from the ALB.

## Why the probe exists

A failed connection from a laptop proves nothing: a laptop has no route to a
private `10.50.10.x` address, so it would fail even if the db allowed everyone.

The probe has every advantage except permission:

- same subnet as the db
- same route table, with the automatic `local` route to the whole VPC
- its own SG lets it send any TCP inside the VPC

Its only difference from the app is the SG attached to it. So when the app
connects and the probe is refused, the db's SG is the cause.

**Trap:** if the probe's own SG allowed no outbound traffic, the test would fail
at the probe, and the db's SG would never be tested. That is why
`probe_all_vpc` exists.

## A route is not permission

Every route table contains a `local` route for the VPC CIDR, and it cannot be
removed. "Public" means only that a table also sends `0.0.0.0/0` to an internet
gateway. Inside the VPC, everything can route to everything. SGs (and NACLs)
are what stop traffic.

The private subnet uses its own empty route table rather than the VPC's main
table. Otherwise, a later internet route added to the main table would make
`private_a` public without anyone noticing.

## Timeout versus refused

| `curl` exit code | What happened | Usual cause |
| --- | --- | --- |
| `0` | connected | allowed |
| `28` | timed out — no reply at all | **SG or NACL silently dropped the packets** |
| `7` | connection refused — instant reply | packet arrived; nothing listening on that port (application problem) |

A security group never replies to blocked traffic. "Hangs until timeout" points
at the network controls; "connection refused" points at the application.

## Security groups versus NACLs

| | Security group | Network ACL |
| --- | --- | --- |
| Rule types | allow only | allow and deny |
| Applies to | each network interface | the whole subnet |
| Return traffic | automatic (stateful) | must be allowed separately (stateless) |
| Typical use | precise, main control | coarse blocks, such as a known bad range |

This lab keeps the default NACL. No NACL drill was done.

## Ways to reach a private instance

| | Bastion host | **EC2 Instance Connect Endpoint** (used) | SSM Session Manager |
| --- | --- | --- | --- |
| What it is | an EC2 instance you run, with a public IP | an AWS-managed interface in your subnet | an agent that calls the SSM service |
| Direction | you → bastion → instance | you → AWS → endpoint → instance | instance → AWS (outbound), you join from AWS's side |
| Inbound port on the instance | 22 from the bastion | 22 from the endpoint's SG | none |
| Private subnet needs NAT or paid endpoints | no | no | yes (`ssm`, `ssmmessages`, `ec2messages`) |
| IAM role on the instance | no | no | yes |
| Who patches it | you | AWS | AWS (you keep the agent current) |
| Cost | instance + public IP, always | free | NAT or interface endpoints, hourly |
| Session recording | do it yourself | who connected, when (CloudTrail) | full session logs possible |

The endpoint was chosen because the instances have no internet route and no
IAM role. Production systems often prefer Session Manager for zero inbound
ports and recorded sessions.

**`preserve_client_ip = false` is required here.** With `true` (Terraform's
default), instances see your laptop's public IP as the source, and
`ssh_from_eice`, which names the endpoint's SG, would not match. A
group-referencing rule only matches traffic that really comes from an interface
with that SG attached.

### Instance Connect Endpoint versus VPC endpoint

| | VPC endpoint (gateway / interface) | EC2 Instance Connect Endpoint |
| --- | --- | --- |
| Who starts the connection | your instance | you, from outside |
| Going to | an AWS service (S3, SSM, ECR…) | your instance's port 22 |
| Replaces | the NAT gateway, for AWS-service traffic | a bastion host |
| Example | lab 03's S3 gateway endpoint | this lab's SSH access |

Both interface endpoints and the Instance Connect Endpoint are network
interfaces with an SG attached, so the same SG rules govern them.

## One private subnet or two?

Production runs at least two copies of each component, one per AZ, so it
needs one subnet per AZ per tier. A subnet alone adds no availability; the
second copy does. This lab runs one app, one db and one probe, so a
`private_b` would stay empty. The ALB is different: AWS refuses to create one
without two subnets in two AZs, which is why `public_b` exists.
