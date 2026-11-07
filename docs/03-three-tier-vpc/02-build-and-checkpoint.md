# Build guide and checkpoint

## Environment and identity

Use the existing Docker/DevPod workspace `eks-lab`, backed by the learning repo
at `~/orca/projects/codex-k8s-projects`; container path `/workspaces/eks-lab`.
The separate host folder `project-17` is not the implementation repository.
Tools stay inside the devcontainer and come from the root `mise.toml`.

The workspace was initially stopped. Docker had other projects' containers;
`devpod list` still showed `eks-lab`. Host commands used to inspect/resume it:

```sh
docker ps --format 'table {{.Names}}\t{{.Status}}'
devpod list
devpod up eks-lab --ide none
```

The local container and SSH do not depend on AWS session validity. Only AWS
requests inside it require current credentials. In the connected container:

```sh
cd /workspaces/eks-lab
mise exec -- aws login --profile authentik --region eu-central-1 --remote
mise exec -- aws sts get-caller-identity \
  --profile authentik-tf --region eu-central-1 --no-cli-pager
```

Expected account `750702271569`, assumed role `AuthentikAdmin`. The learner
confirmed the account. CLI login uses `authentik`; Terraform uses `authentik-tf`.
Login URLs, codes, AWS config and caches remain private.

### Session-duration follow-up

The role originally reported 3600 seconds. The Authentik blueprint also requested
3600. At the user's explicit request, both were changed to 14400 seconds:

- AWS role maximum was read back as `14400`.
- `homelab/authentik/blueprints/aws-saml.yaml` and its README were committed in
  [homelab commit 31d4eb3](https://github.com/nazmur96/homelab/commit/31d4eb3933e88a8eb484447e4d7ee09bd5d025c8).
- Server pulled that commit; blueprint was applied. Live Authentik mapping
  read `return "14400"` and was attached to the AWS provider.
- Existing sessions keep their original expiry. A fresh AWS browser sign-in
  through Authentik and a fresh `aws login --remote` are needed. The learner
  later reported an expired session and renewed access; a newly issued token's
  actual four-hour lifetime was **not captured**.

This IAM role remains CLI-managed according to its owning repository; the
Authentik half is declarative. Neither identity component belongs to this
lab's Terraform state or cleanup scope.

## Files written so far

Implementation: [labs/03-three-tier-vpc](https://github.com/nazmur96/codex-k8s-projects/tree/main/labs/03-three-tier-vpc).
The [complete source snapshot](https://github.com/nazmur96/codex-k8s-projects/blob/main/docs/03-three-tier-vpc/04-checkpoint-source.md)
contains full contents for the current checkpoint, not a finished deployable lab.

| File | Contents |
| --- | --- |
| `versions.tf` | Terraform `1.17.1`, AWS provider `~> 6.0` |
| `providers.tf` | Frankfurt, Authentik TF profile, allowed account and default tags |
| `vpc.tf` | VPC CIDR and DNS |
| `subnets.tf` | Six-entry map and subnet `for_each` |
| `gateways.tf` | IGW, NAT Elastic IP, single zonal public NAT |
| `routes.tf` | Four custom route tables, routes and six associations |
| `endpoints.tf` | S3 gateway endpoint on API route tables |
| `security-groups.tf` | Three security groups |
| `security-group-rules.tf` | Three ingress and three egress rules |
| `alb.tf` | ALB, port-80 listener, port-8080 instance target group |
| `outputs.tf` | VPC/subnet/SG IDs, ALB URL and target-group ARN |
| `compute.tf` | Amazon Linux 2023 AMI data lookups only; no EC2 resources |
| `iam.tf` | API role, standard SSM policy attachment and instance profile |
| `templates/api.py.tftpl` | Python health/identity/database-TCP API; not yet wired to EC2 |
| `.terraform.lock.hcl` | Selected AWS provider `6.72.0` with integrity hashes |

The learner writes implementation and runs project commands. The agent inspects
saved files and handles requested documentation/GitHub updates. During this
checkpoint update, the agent repaired accidental trailing `A` lines and restored
the missing HTTP-server startup line in the API template. No workload/instance
configuration was silently added.

## Checks and observations

The learner ran these before later ALB/IAM/application additions and reported
all successful:

```sh
cd /workspaces/eks-lab/labs/03-three-tier-vpc
mise exec -- terraform fmt
mise exec -- terraform init -backend=false
mise exec -- terraform validate
```

`init -backend=false` installs provider dependencies without configuring a
backend. It is not an infrastructure deployment. Later agent checks are
recorded in the validation section below. Validation cannot prove account
permissions, networking, application health or a working database.

The learner's read-only instance-type query returned `t3.micro`, `t3.small`,
`t8i.micro`, `t8i.small`, `c7i-flex.large` and `m7i-flex.large` as Free Tier
eligible x86-64 types. `t3.micro` was selected provisionally for the two APIs
and one database. Eligibility is not zero-cost assurance, an AZ offering check,
or a capacity guarantee. Confirm sizing, quotas, AMI architecture and current
availability before the first plan/apply.

```sh
mise exec -- aws ec2 describe-instance-types \
  --filters \
    'Name=free-tier-eligible,Values=true' \
    'Name=processor-info.supported-architecture,Values=x86_64' \
  --profile authentik-tf --region eu-central-1 \
  --query 'InstanceTypes[].{Type:InstanceType,vCPU:VCpuInfo.DefaultVCpus,MemoryMiB:MemoryInfo.SizeInMiB}' \
  --output table --no-cli-pager
```

## Infrastructure still to write — not just deploy and test

1. API startup template: write the rendered program, run it as a non-root
   service, install required packages through permitted paths, and persist
   service startup across reboot.
2. Database bootstrap and management: select a concrete PostgreSQL installation
   method. Its current route table has no default egress, its SG has no outbound
   rules, and it has no SSM endpoints or role. An internet package install or
   SSM assumption would fail. Do not quietly attach NAT to the database tier;
   decide on a prebuilt image or scoped private bootstrap path first.
3. Two API EC2 resources and one database EC2 resource: choose instance/AMI,
   encrypted root disks, IMDSv2, subnet/SG/profile bindings and startup ordering.
   The API startup must wait for functional outbound routing if it downloads
   packages; references to subnet IDs alone do not ensure NAT/routes are ready.
4. Two ALB target-group attachments and useful instance outputs.
5. State storage: explicitly choose local state with private backup for this
   single-user lab, or implement a separate remote backend. No decision has
   been made. Project #16's backend bucket is deleted; never point at it blindly.
6. NACL drill/rollback and the detailed negative-proof procedure. No custom
   NACL is required merely to duplicate SG rules.

After implementation: validate, inspect a fresh plan, recheck account-wide
budget/current spend and current prices, obtain explicit creation approval,
then let the learner run the apply. No approval to create billed resources or
run apply/destroy is implied by this documentation request.

## Validation for this Git checkpoint

Agent-captured results on November 7, 2026:

| Check | Result and limit |
| --- | --- |
| Container `terraform fmt -check` | Passed on current Terraform files |
| Container `terraform validate` | `Success! The configuration is valid.` |
| API template sample syntax | After substituting a sample private IP, Python AST parsing passed and the server-start line was present |
| `git diff --check` | Passed |

The existing devcontainer has no Python executable; the attempted Python check
there could not run. For syntax checking only, the template was sent over SSH
stdin to the existing Python runtime in the management server's Authentik worker
container. No package was installed, no application was launched, and no server
configuration was changed. This is not proof of EC2 startup or runtime behavior.
The future API bootstrap still needs to provide its Python runtime explicitly.

There is no Terraform apply, live ALB URL, target health, API/database connection
result or project #17 destroy result at this checkpoint.
