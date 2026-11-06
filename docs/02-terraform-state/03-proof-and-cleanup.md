# Proofs, troubleshooting and cleanup

## Proof 1 — a clean plan

**DevPod terminal, `/workspaces/eks-lab/labs/02-terraform-state/environments/dev`:**

```sh
mise exec -- terraform plan -detailed-exitcode
echo "Plan exit code: $?"
```

Run the echo immediately afterward so it captures Terraform's exit status.

| Exit code | Meaning |
| --- | --- |
| 0 | Successful plan with no changes |
| 1 | Error |
| 2 | Successful plan proposing changes |

Actual supplied output after initial apply:

```text
No changes. Your infrastructure matches the configuration.
Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
Plan exit code: 0
```

This proves agreement at that moment for the managed configuration. It is not a permanent guarantee against future drift.

## Proof 2 — two applies compete for one state lock

Use two SSH sessions into the SAME devcontainer, both targeting the SAME dev root and backend key. No new environment or host tools are needed.

### Prepare a small change

The original dev root had no Exercise tag. We added this line inside the module call's existing tags map:

```hcl
Exercise = "state-locking"
```

Then ran:

```sh
mise exec -- terraform fmt
mise exec -- terraform plan
```

Learner supplied summary: 0 added, 3 changed, 0 destroyed. The intended change was adding that tag to the VPC and two subnets.

For a future replay using the final committed source, the tag already exists. Change its value to a new harmless value, review the plan, and obtain fresh approval for both apply attempts. A no-change apply may finish too quickly to demonstrate contention.

### Terminal A: hold the lock

After explicit approval covering the tag update and both apply attempts, run in the dev root:

```sh
mise exec -- terraform apply
```

Check that the plan contains only the intended tag changes. **Leave it waiting at `Enter a value:`. Do not enter yes yet.** The learner confirmed reaching this prompt and leaving it unanswered.

### Terminal B: attempt the competing apply

From a second host terminal:

```sh
ssh eks-lab.devpod
```

Inside that second container session:

```sh
cd /workspaces/eks-lab/labs/02-terraform-state/environments/dev
mise exec -- terraform apply -lock-timeout=5s
```

Expected: wait for the lock, then fail. Actual supplied output included:

```text
Acquiring state lock. This may take a few moments...
Error: Error acquiring the state lock
S3: PutObject ... StatusCode: 412 ... PreconditionFailed
Path: nazmur96-tfstate-750702271569-euc1/project-16/dev/terraform.tfstate
Operation: OperationTypeApply
Version: 1.17.1
```

Request IDs and the temporary lock ID are omitted because they are unnecessary for understanding the proof. S3 refused the competing lock creation. This is the expected protective behavior, not evidence of state corruption. Terminal B did not get to apply changes.

Do not follow the error's suggestion to disable locking. Do not delete the lock object or force-unlock while terminal A is active.

### Terminal A: finish normally

Return to the waiting prompt and enter `yes` to complete the already approved update. The learner reported apply complete; raw resource totals were not supplied for this apply. Terraform normally saves the resulting state and releases the lock.

### Terminal B: check the release and final consistency

```sh
mise exec -- terraform plan -detailed-exitcode
echo "Plan exit code: $?"
```

Expected: no lock error, no changes, exit code 0. The learner replied complete after this instruction. The final repeat is therefore learner-confirmed; its raw output was not captured. The earlier clean-plan output and contention error were captured directly.

## Additional read-only checks

These are useful checks to run next; their output was not captured during the session:

```sh
mise exec -- terraform state list
mise exec -- terraform output
mise exec -- aws s3api head-object \
  --bucket nazmur96-tfstate-750702271569-euc1 \
  --key project-16/dev/terraform.tfstate \
  --profile authentik-tf --region eu-central-1 --no-cli-pager
```

Expected state addresses:

```text
module.network.aws_subnet.main["private_a"]
module.network.aws_subnet.main["private_b"]
module.network.aws_vpc.main
```

Head-object reads metadata without printing the state contents. Backend initialization and lock-error output demonstrate use of S3; a separate state-object metadata readback remains an optional additional check.

## Troubleshooting from this session

### Expired AWS credentials

Terraform validation passed, but planning failed with no valid credential sources and a credential_process error. An AWS identity check revealed session expiry. We renewed the existing Authentik login and retried the plan successfully.

```sh
mise exec -- aws login --profile authentik --region eu-central-1 --remote
mise exec -- aws sts get-caller-identity --profile authentik-tf --region eu-central-1
```

Keep authentication links, codes and tokens private. Do not create access keys as a workaround.

### SSH failed because Docker was down

DevPod SSH initially reported it could not connect to `/var/run/docker.sock`. Host systemd reported start-limit-hit. Docker logs showed containerd waiting on its Bolt metadata database and timing out.

Read-only host diagnostics used:

```sh
systemctl status docker.service docker.socket --no-pager
journalctl -u docker.service -b -n 100 --no-pager
ps -eo pid,ppid,stat,etime,args | rg 'dockerd|containerd'
df -h /var/lib/docker
df -i /var/lib/docker
```

No dockerd/containerd processes were visible at the process check. Disk had 746 GB free. The filesystem's zero inode counts did not establish inode exhaustion. The root cause of the database-open delay was not proven; do not label it corruption or a stale lock without evidence.

The learner then ran on the host:

```sh
sudo systemctl reset-failed docker.service docker.socket
sudo systemctl start docker.service
```

A subsequent agent read-only `docker ps` confirmed a responding daemon and restarted containers. The learner restarted eks-lab through DevPod and reconnected successfully. Starting shared Docker also brought other restart-configured containers up. No Docker data was deleted, and no NixOS configuration change was made. Do not copy these recovery commands blindly into another incident; inspect the cause and coordinate shared-runtime impact first.

### Old files still existed after container restart

That was expected: DevPod mounts the host repository. A disposable container can have persistent project files. Old saved EKS plans were not reused. Do not delete state to make a directory look clean.

## Earlier EKS lab cleanup recovered before this build

The earlier README still marked cleanup unconfirmed. On November 6 the learner reported:

| Check | Supplied result |
| --- | --- |
| Old root `terraform state list` | Empty |
| AWS caller identity | Account 750702271569, AuthentikAdmin role |
| `aws eks describe-cluster --name eks-lab` | ResourceNotFoundException |
| VPC filter `Name=tag:Name,Values=eks-lab-vpc` | Empty list |
| Elastic IP filter `Name=tag:Name,Values=eks-lab-nat-eip` | Empty list |

These establish that the tracked state was empty and those named resources were absent. A separate scan for orphaned EBS volumes was not captured; do not describe these targeted checks as a complete account-wide cost audit. Podinfo resources were outside the scope of the checks.

## Cleanup procedure — subsequently completed

Build/proof completion is separate from cleanup completion. The original instructions below were written before cleanup; the final completion record at the end supersedes that pending checkpoint. Preserve both states. Destroying a container does not delete AWS resources.

### A. Disposable dev network

First inspect a fresh destroy plan in the dev root:

```sh
cd /workspaces/eks-lab/labs/02-terraform-state/environments/dev
mise exec -- terraform plan -destroy
```

Expected scope: exactly the two module subnets and VPC. **Obtain explicit approval before running destroy.** Once approved, the learner runs:

```sh
mise exec -- terraform destroy
```

Review the new proposal before entering yes. Do not use stale saved plans. On errors, keep state and inspect partial resources instead of deleting records.

After successful destruction, verify:

```sh
mise exec -- terraform state list
mise exec -- aws ec2 describe-vpcs \
  --filters 'Name=tag:Name,Values=tfstate-lab-dev-vpc' \
  --profile authentik-tf --region eu-central-1 \
  --query 'Vpcs[].VpcId' --no-cli-pager
mise exec -- aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=tfstate-lab-dev-private_a,tfstate-lab-dev-private_b' \
  --profile authentik-tf --region eu-central-1 \
  --query 'Subnets[].SubnetId' --no-cli-pager
```

Expected: empty state list and empty AWS arrays. Record actual results before marking cleanup complete.

### B. Backend bucket: a separate lifecycle decision

Keep the bucket available through network destruction so Terraform can write the final state. Then explicitly decide whether to retain it for future labs or remove it.

Retaining it also retains versions and associated storage/request costs. Bootstrap's local state continues to manage it. Back it up privately; `.gitignore` prevents publication, not data loss.

Removing it requires a separate approved sequence: confirm no other root uses the bucket, preserve any needed state privately, deliberately remove the prevent_destroy guard from committed configuration, review every current object and historical version/delete marker, and approve removing bucket contents and destroying bootstrap. An ordinary object deletion does not purge version history. `force_destroy = false` intentionally prevents silently emptying the bucket.

No bucket-emptying or destruction command is provided for blind execution. Do not enable force_destroy casually or delete the bucket while another configuration still depends on its backend.

## Git hygiene

Commit `.tf` sources, documentation, and both roots' `.terraform.lock.hcl` files. Do not commit `.terraform/`, state or backups, plans, tfvars, AWS files, login material, or kubeconfig. This lab has no kubeconfig requirement. Internal documentation links use absolute GitHub URLs.


## Final cleanup checkpoint — November 6, 2026

- Learner supplied `Destroy complete! Resources: 3 destroyed.` for both subnets and the VPC.
- Learner confirmed empty dev state and empty AWS VPC/subnet tag-filter results.
- User explicitly authorized the agent to remove the backend and all its versions.
- Agent inspected the bucket: only this lab's state/lock keys, 12 stored object versions and 9 delete markers; no current active lock. Dev state was independently verified empty.
- Agent temporarily removed prevent_destroy, generated and checked a fresh plan containing only the four bootstrap deletions, and deleted all versions and delete markers.
- The first cleanup script stopped because a successful quiet delete returned no JSON. A follow-up listing verified the bucket was empty before proceeding.
- Captured backend result: `Apply complete! Resources: 0 added, 0 changed, 4 destroyed.`
- Agent verified empty bootstrap state and absence of the bucket from AWS list-buckets.
- Restored the example's prevent_destroy guard afterward for safe future reuse. No resources were recreated.

**Project #16 build, proofs, and cleanup are complete.** The dev backend still points to the now-deleted bucket; a future rebuild must create bootstrap first. Do not reuse old plans. Local ignored states and plans were not published. No Podinfo resources were changed.
