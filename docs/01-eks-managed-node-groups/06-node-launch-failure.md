# Incident: managed node group could not launch instances

## Symptom and impact

The first Terraform apply failed on `aws_eks_node_group.main`. AWS reported:

```text
CREATE_FAILED
AsgInstanceLaunchFailures: Could not launch On-Demand Instances.
InvalidParameterCombination - The specified instance type is not eligible for Free Tier.
```

The EKS control plane was ACTIVE, but the requested t3.medium workers could not launch. The failed node group remained in AWS and Terraform state. CoreDNS had not been created because it depended on successful node-group creation. Existing infrastructure could continue consuming credits or incurring charges despite the apply failure.

## Diagnosis

Read-only inspection of the node group confirmed the launch error and configured instance type. The first diagnostic attempts failed because the authentication session had expired. The learner renewed the session:

```sh
mise exec -- aws login --profile authentik --region eu-central-1 --remote
```

Then queried eligible instance types:

```sh
mise exec -- aws ec2 describe-instance-types \
  --filters Name=free-tier-eligible,Values=true \
  --profile authentik-tf \
  --region eu-central-1 \
  --query 'InstanceTypes[].{Type:InstanceType,vCPUs:VCpuInfo.DefaultVCpus,MemoryMiB:MemoryInfo.SizeInMiB}' \
  --output table
```

The learner's actual output:

| Type | vCPUs | Memory MiB |
| --- | --- | --- |
| c7i-flex.large | 2 | 4096 |
| m7i-flex.large | 2 | 8192 |
| t3.micro | 2 | 1024 |
| t3.small | 2 | 2048 |
| t4g.micro | 2 | 1024 |
| t8i.micro | 2 | 1024 |
| t8i.small | 2 | 2048 |
| t4g.small | 2 | 2048 |

The proven immediate cause was AWS rejecting t3.medium under the account's eligibility restriction. The exact account plan was not independently confirmed. No account upgrade was performed. Free Tier eligibility is not a guarantee of zero charges; credits and limits still apply.

## Recovery

Changed `instance_types` in nodes.tf from `["t3.medium"]` to `["t3.small"]`. This kept x86 compatibility with our chosen AL2023 image and provided two nodes with 2 vCPUs and 2 GiB RAM each. We did not choose Arm t4g instances because they would require the corresponding architecture configuration and compatible images.

```sh
mise exec -- terraform fmt
mise exec -- terraform validate
mise exec -- terraform plan -out=eks-lab-recovery.tfplan
```

The saved recovery plan was independently inspected:

```text
Plan: 2 to add, 0 to change, 1 to destroy.
```

- Replace the failed node group with t3.small workers.
- Create CoreDNS.
- Preserve the remaining existing infrastructure.

After explicit approval for this new apply:

```sh
mise exec -- terraform apply eks-lab-recovery.tfplan
```

The learner confirmed successful completion. Subsequent evidence showed two Ready workers, healthy system pods, successful internal DNS resolution, and a Ready NGINX test application. The smaller nodes were sufficient for this demonstrated workload; this does not establish capacity for larger applications.

## Lessons and prevention

- A valid configuration and successful plan do not guarantee EC2 can launch the chosen capacity.
- Check account restrictions, eligible types, image architecture, and regional availability before deployment.
- A failed apply can leave working, billable resources; preserve state and inspect partial creation.
- Review a fresh recovery plan instead of rerunning the original saved plan after configuration changes.
- Do not delete Terraform state or make unrelated manual changes to solve an instance eligibility error.
- Record actual verification results rather than treating successful provisioning as proof of a working cluster.

## Review questions

1. Why did validation and planning pass even though node creation failed?
2. Why was replacing only the node group preferable to destroying the entire VPC and cluster?
3. Why would changing from t3 to t4g require checking architecture settings?
4. Why can an unsuccessful apply still consume credits or incur charges?
5. What proves the recovered cluster works beyond an Apply complete message?

[AWS Free Tier account plan restrictions](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html)
