# Deployment record and evidence

## Current checkpoint

**2026-11-05: apply in progress, as reported by the learner.** No successful final apply summary, Ready nodes, DNS result, workload result, or cleanup has been recorded yet. Do not interpret the presence of Terraform files as proof of a working cluster.

## Validate and save the plan

Inside /workspaces/eks-lab/terraform:

```sh
mise exec -- terraform fmt
mise exec -- terraform validate
mise exec -- terraform plan -out=eks-lab.tfplan
```

Validation succeeded. The learner reported:

```text
Plan: 32 to add, 0 to change, 0 to destroy.
```

The saved plan was independently inspected read-only. All 32 changes were creates: VPC (1), subnets (4), internet gateway (1), EIP (1), NAT (1), route tables (2), routes (2), subnet associations (4), IAM roles (3), policy attachments (4), cluster (1), node group (1), access entry/policy association (2), add-ons (4), and Pod Identity association (1).

Managed resources also create underlying objects such as worker instances and root volumes; 32 is not the total number of every AWS object or a billing-unit count. The plan is excluded from Git and should be treated as potentially sensitive.

## Approved apply

After reviewing estimated costs, the learner approved creation with the intent to test and promptly clean up. The instructed command was:

```sh
mise exec -- terraform apply eks-lab.tfplan
```

A saved-plan apply executes without another interactive approval prompt. Creation was expected to take roughly 15–30 minutes, but this is not a timeout guarantee. The learner subsequently reported resources were still being created.

Do not start a second apply, edit the running deployment's configuration, migrate its backend, delete its lock file, or move its working directory while it runs. If it errors, preserve the output and state and inspect partial creation before retrying or cleaning up. Partial deployment may already incur charges.

## Evidence still required

| Requirement | Status | Evidence to capture |
| --- | --- | --- |
| Terraform apply | In progress | Final summary or actual error |
| EKS and managed node group | Pending | AWS status and health |
| kubectl connection | Pending | Dedicated kubeconfig/context and authenticated access |
| Node registration | Pending | Expected nodes show Ready |
| Managed add-ons | Pending | ACTIVE status and healthy Kubernetes workloads |
| CoreDNS functionality | Pending | DNS lookup from a test pod succeeds |
| Test microservice | Pending | Workload rollout completes and pod is Ready |
| Network controls | Pending | Inspect actual EKS/node security groups and private node addresses |
| Cleanup | Pending | Approved destroy, empty managed state, and checks for remaining billed resources |

We will add the commands and actual results as each verification is performed. No workload, load balancer, or application ingress has been deployed as part of this checkpoint.

## Cleanup remains required

Closing SSH, Cursor, Orca, or the container does not stop AWS charges. Request explicit approval before Terraform destroy, run cleanup using the preserved state, and verify EKS, nodes, NAT, public IP allocation, and managed storage are removed. This documentation update does not run or authorize a destroy by itself.
