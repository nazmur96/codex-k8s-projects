# Kubernetes Projects

Hands-on Kubernetes learning projects: understand the components, build with Terraform, and collect evidence that the result works.

## Project 01: Amazon EKS with managed node groups

**Goal:** provision a minimal EKS cluster with Terraform and understand its networking, IAM roles, worker nodes, and core add-ons.

Planned infrastructure:

- VPC, subnets, routing, and security groups.
- EKS cluster IAM role and EC2 node IAM role; dedicated workload permissions where needed.
- EKS control plane and a managed node group.
- Managed VPC CNI, CoreDNS, and kube-proxy add-ons.

An add-on supplies a supporting capability: VPC CNI handles pod networking, CoreDNS resolves internal service names, and kube-proxy supports Kubernetes Service traffic.

### Progress

- [x] Configure a Docker-backed development container.
- [x] Pin and verify project tools with mise inside the container.
- [x] Make existing AWS profiles available through a local bind mount.
- [x] Complete keyless Authentik-backed AWS CLI login and verify the CLI identity.
- [ ] Verify the separate Terraform AWS profile.
- [ ] Verify budget alerts and estimate the selected infrastructure cost.
- [ ] Write and review Terraform networking and IAM configuration.
- [ ] Provision EKS, managed nodes, and add-ons.
- [ ] Prove nodes register as Ready.
- [ ] Prove DNS resolves from a test pod.
- [ ] Prove a test workload becomes Ready.
- [ ] Destroy the lab and verify cleanup.

**Current state:** development environment prepared. No Terraform infrastructure has been written or applied, and no billable AWS infrastructure has been created by this project.

## Development environment

Docker runs the container; DevPod creates it and provides SSH access. The devcontainer defines Ubuntu userland, and mise installs the declared project tools inside it. A graphical editor is optional.

| Tool | Pinned version |
| --- | --- |
| Terraform | 1.17.1 |
| AWS CLI | 2.39.3 |
| kubectl | 1.37.2 |

The EKS Kubernetes version has not been selected. Check kubectl compatibility before selecting it.

The container uses the Linux user `vscode`; this name comes from the base image and does not require the VS Code editor.

### 1. Check host prerequisites

Run on the **host**:

```sh
mise --version
devpod version
docker --version
docker info
```

Docker was selected instead of Podman because of networking issues encountered with Podman. Project tools belong inside the development container.

### 2. Declare tools and the container

The committed `mise.toml` pins tool versions. `.devcontainer/devcontainer.json` installs mise and runs:

```sh
mise trust && mise install
```

That command runs **inside the container** during creation. Running `mise exec` on the host can automatically install missing tools on the host; avoid doing that for this project.

### 3. Start and enter the container

From the project directory on the **host**:

```sh
devpod up . --id eks-lab --provider docker --ide none
ssh eks-lab.devpod
```

We also tried `--ide cursor`, which launched Cursor. An editor window opening does not prove its terminal is inside the container. SSH from an Orca terminal was verified and is our working terminal workflow.

Inside the **container**:

```sh
test -f /.dockerenv && echo "Inside Docker" || echo "Outside Docker"
pwd
mise exec -- terraform version
mise exec -- aws --version
mise exec -- kubectl version --client
```

Verified project path: `/workspaces/eks-lab`. Keep one host terminal and one container terminal open. `exit` leaves the SSH session without stopping the container.

### 4. Share the existing AWS configuration

Initially, this command returned no profiles inside the container:

```sh
mise exec -- aws configure list-profiles
```

The host already had the required profiles. We added this bind mount to the devcontainer configuration:

```json
"mounts": [
  "source=${localEnv:HOME}/.aws,target=/home/vscode/.aws,type=bind"
]
```

This exposes the host's existing AWS configuration and login cache to the container. It is writable so login can update its session. It does not copy those files into Git. Only use this mount with trusted containers.

After changing mounts, recreate from the **host**, then reconnect:

```sh
devpod up . --id eks-lab --provider docker --ide none --recreate
ssh eks-lab.devpod
```

Check inside the **container**:

```sh
mise exec -- aws configure list-profiles
```

Both `authentik` and `authentik-tf` were visible after recreation.

### 5. Authenticate through Authentik

Authentication is keyless, through the existing Authentik federation and `AuthentikAdmin` role. No IAM access keys are created.

Run inside the **container**:

```sh
mise exec -- aws login --profile authentik --region eu-central-1 --remote
```

Follow the browser approval instructions privately. A browser AWS Console session does not by itself authenticate the CLI.

Our initial login without `--remote` failed at the browser's `127.0.0.1` callback: the browser was on the host while the listener was inside the container. We cancelled it with Ctrl+C and used `--remote` successfully.

Verify the CLI session:

```sh
mise exec -- aws sts get-caller-identity --profile authentik --region eu-central-1
```

The expected Authentik-backed account and role were confirmed. Do not commit login URLs, authorization codes, tokens, or session caches.

**Next check, not yet verified:**

```sh
mise exec -- aws sts get-caller-identity --profile authentik-tf --region eu-central-1
```

Terraform will use `AWS_PROFILE=authentik-tf`. We will verify that profile before running Terraform against AWS.

## Cost and change controls

- Verify an AWS budget alert before creating infrastructure. Alerts are notifications, not a spending cap.
- Estimate the chosen region, node size, storage, and network configuration before applying.
- EKS standard-support control-plane pricing is $0.10/hour; EC2, EBS, networking, and other selected services are additional. Recheck current regional pricing before deployment: https://aws.amazon.com/eks/pricing/
- Obtain explicit approval before billed AWS resource creation and every Terraform apply or destroy.
- Destroy lab resources at the end of each session, with approval, and verify cleanup. Closing a terminal does not stop AWS charges.

## How this repository will grow

Add configuration, explanations, troubleshooting notes, and actual validation evidence as each step is completed. Keep planned steps separate from verified results. GitHub documentation is part of the project; publishing an article is a later, explicitly requested step.
