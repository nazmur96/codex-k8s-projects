# Design and concepts

## Inventory

| Component | Count | Purpose / current implementation |
| --- | --- | --- |
| VPC | 1 | `10.40.0.0/16`, DNS support and hostnames enabled |
| AZs used | 2 | `eu-central-1a`, `eu-central-1b`; AZs already exist |
| Subnets | 6 | Public, API and database subnet in each AZ |
| Internet gateway | 1 | Attached to VPC, shared by public routing |
| Zonal public NAT | 1 | In public A, used by both API subnets |
| Elastic IP | 1 | NAT's public IPv4 address, not the ALB's |
| Custom route tables | 4 | Public shared, API A, API B, database shared |
| Explicit subnet associations | 6 | Every subnet selects its intended table |
| Security groups | 3 | ALB, API, database |
| S3 gateway endpoint | 1 | Associated with both API route tables |
| ALB / listener / target group | 1 each | HTTP 80 → HTTP 8080; health path `/health` |
| API IAM role / instance profile | 1 each | Standard SSM agent permissions |
| API EC2 instances | 2 planned | Not yet declared |
| Database EC2 instance | 1 planned | Not yet declared; no RDS |

AWS also creates default VPC objects, including the main route table and default
NACL. The four custom tables are in addition to the main table, which none of
our six explicitly associated subnets uses.

## Addressing and routes

`10.40.0.0/16` covers `10.40.0.0` through `10.40.255.255`. Each selected `/24`
contains 256 addresses, of which AWS reserves five, leaving 251 usable.
Ranges are non-overlapping within this lab. Connectivity to other networks
would require checking their ranges too.

| Table | Associations | Routes beyond automatic VPC local route |
| --- | --- | --- |
| Public | `public_a`, `public_b` | `0.0.0.0/0 → IGW` |
| API A | `api_a` | `0.0.0.0/0 → NAT`; regional S3 prefix list → endpoint |
| API B | `api_b` | Same NAT; regional S3 prefix list → endpoint |
| Database | `database_a`, `database_b` | None |

A subnet is public because its table has a direct internet-gateway route.
Automatic public-IP assignment is disabled on all six subnets. Individual
IPv4 workloads need a public address and security permission for direct
internet connectivity; the public ALB and NAT manage their addresses separately.

Three custom tables could work with one shared API table. We chose separate
API tables so a future same-AZ NAT per API tier can be configured independently.
The single NAT saves fixed lab cost but allows cross-AZ traffic and makes both
API subnets' internet egress depend on AZ A. Local API/database traffic does
not pass through NAT. The more-specific local and S3 routes win over `/0`.

An isolated database subnet has no internet default route. It can still route
to the VPC's other subnets; isolation from unwanted workloads requires traffic
permissions as well.

## Security groups and NACLs

| Initiator | Destination | Permission |
| --- | --- | --- |
| Internet | ALB TCP 80 | ALB ingress from `0.0.0.0/0` |
| ALB | API TCP 8080 | ALB egress to API SG + API ingress from ALB SG |
| API | Database TCP 5432 | API egress to database SG + database ingress from API SG |
| API | Public HTTPS TCP 443 | API egress to `0.0.0.0/0`; routing chooses NAT or S3 endpoint |

Security groups attach to resources' network interfaces, not to subnets.
Referencing a source group permits traffic from associated resources rather
than an entire subnet CIDR. Security groups are stateful: replies to permitted
connections do not need reverse rules. These Terraform-created groups have
no general allow-all egress rule. Database-initiated outbound traffic has not
been permitted. API HTTPS egress allows any IPv4 destination on TCP 443; it is
not a domain-name allowlist.

NACLs apply at subnet boundaries and are stateless, so both directions,
including response ports, must be accounted for. We initially retain the
default NACL. A scoped blocking drill and rollback remain to be designed;
no custom NACL protection or completed NACL proof is claimed.

HTTP is for a temporary lab without real credentials or sensitive data.
Production HTTPS would need a certificate, listener and related decisions.

## NAT and VPC endpoints together

VPC endpoint is the general category; **gateway** is the type and **S3** is
the target service. This endpoint creates no bucket and grants no IAM access
to objects. It adds regional S3 routes to API tables. General internet HTTPS
still uses NAT. Gateway endpoints have no additional endpoint charge; interface
endpoints are a different type with hourly/data charges.

We briefly considered omitting S3 access because the test API does not require
it, then retained the endpoint to learn routing alongside NAT. No S3 application
dependency is claimed. The endpoint path must be checked during proof.

References: [AWS NAT architecture example](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-example-private-subnets-nat.html),
[gateway endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html),
[NAT cost considerations](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-pricing.html).

## Terraform and application concepts

| Construct | Meaning |
| --- | --- |
| `resource` | Declares something Terraform manages |
| `data` | Reads an existing object's attributes |
| `locals { ... }` | Declares reusable values, referenced as `local.name` |
| Resource `for_each` | Creates independently tracked instances from map/set entries |
| `each.key` / `each.value` | Current entry's name and contents |
| `aws_subnet.this["api_a"].id` | Selects one subnet instance and its AWS ID |
| `for name, subnet ... : name => subnet.id` | Builds an output map; creates no resources |
| `output` | Exposes a selected result; grants no permissions |
| `.tftpl` | Template consumed explicitly by Terraform, not loaded as a `.tf` file |

Terraform reads all `.tf` files in this directory as one configuration. A file
named `security-groups-rules.tf` would work too; we renamed it for consistency.

The Python template is the future application, not infrastructure. Terraform
will render `database_host` into a quoted Python string, and future EC2 startup
configuration must write and run it. The template is currently unreferenced.
`/health` returns 200, `/` identifies the host, and `/db` attempts a TCP
connection to port 5432. That is a network probe, not SQL/authentication proof.
Listening on `0.0.0.0:8080` means all local IPv4 interfaces, not automatic public
exposure. Private addressing and the API SG still control access.
