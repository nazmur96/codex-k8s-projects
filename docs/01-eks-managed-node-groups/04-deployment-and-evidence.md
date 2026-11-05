# Deployment record and evidence

## Current checkpoint

**2026-11-05: build and the three required proofs completed.** The first apply failed to launch workers; the recovery apply succeeded. Two nodes were Ready, system pods were healthy, DNS resolved from a test pod, and the learner confirmed the NGINX rollout and Ready pod. Destroy was explicitly approved and the command provided; its final result and post-destroy verification are still pending.

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

## Node-group failure and recovery

The first apply created much of the infrastructure but failed on the node group with `CREATE_FAILED` / `AsgInstanceLaunchFailures`. AWS rejected t3.medium as not eligible for the account’s Free Tier restriction. Read-only inspection confirmed the cluster was ACTIVE and the failed node group still referenced t3.medium. CoreDNS had not been created because it depended on the node group. See the full incident record in guide 06.

The session had expired during diagnosis. After remote reauthentication, we queried eligible instance types and selected x86 t3.small (2 vCPU, 2 GiB RAM). Two nodes were sufficient for the actual minimal workload, as later proven. Free Tier eligibility does not guarantee zero cost; account credits and limits apply.

Changed only the instance type in nodes.tf, then ran:

```sh
mise exec -- terraform fmt
mise exec -- terraform validate
mise exec -- terraform plan -out=eks-lab-recovery.tfplan
```

Reported and independently inspected plan:

```text
Plan: 2 to add, 0 to change, 1 to destroy.
```

It deleted/recreated the failed node group using t3.small and created CoreDNS, preserving the other managed resources. After explicit recovery-apply approval:

```sh
mise exec -- terraform apply eks-lab-recovery.tfplan
```

The learner reported apply completed successfully. The exact final resource-count summary was not supplied. The original t3.medium cost estimate is historical; smaller workers reduce compute cost, while EKS/NAT costs remain. No measured final bill is available.

## Configure kubectl separately from other projects

Run inside the devcontainer:

```sh
export KUBECONFIG=/home/vscode/.kube/eks-lab-config
mise exec -- aws eks update-kubeconfig \
  --name eks-lab \
  --region eu-central-1 \
  --profile authentik-tf \
  --alias eks-lab
mise exec -- kubectl get nodes -o wide
```

Kubeconfig contains the cluster connection and authentication configuration. It is outside the repository. The export applies to this shell session; repeat it in another shell when using this file.

### Proof 1: workers registered and Ready

The learner supplied:

| Node | Status | Internal IP | External IP | Kubernetes version |
| --- | --- | --- | --- | --- |
| ip-10-20-10-253.eu-central-1.compute.internal | Ready | 10.20.10.253 | none | v1.37.1-eks-6e7947a |
| ip-10-20-11-47.eu-central-1.compute.internal | Ready | 10.20.11.47 | none | v1.37.1-eks-6e7947a |

Both ran Amazon Linux 2023.12.20261102 with containerd 2.3.7+unknown. Their addresses place them in our two private subnet ranges. ROLES `<none>` refers to Kubernetes role labels, not missing IAM roles.

## Inspect system components

```sh
mise exec -- kubectl get pods -n kube-system -o wide
```

The learner supplied these results; every listed pod was Running with zero restarts:

| Component | Pod | Ready | Node private IP |
| --- | --- | --- | --- |
| VPC CNI | aws-node-lhtpg | 2/2 | 10.20.11.47 |
| VPC CNI | aws-node-qmk99 | 2/2 | 10.20.10.253 |
| CoreDNS | coredns-f86d6d8f8-9x4q2 | 1/1 | 10.20.11.47 |
| CoreDNS | coredns-f86d6d8f8-mqmlm | 1/1 | 10.20.10.253 |
| Pod Identity Agent | eks-pod-identity-agent-5kkhf | 1/1 | 10.20.11.47 |
| Pod Identity Agent | eks-pod-identity-agent-d6k4g | 1/1 | 10.20.10.253 |
| kube-proxy | kube-proxy-4f8s9 | 1/1 | 10.20.10.253 |
| kube-proxy | kube-proxy-jthkf | 1/1 | 10.20.11.47 |

This demonstrates Kubernetes pod health. A separate final AWS add-on ACTIVE-status response and live security-group rule inspection were not captured.

### Proof 2: DNS resolves from a pod

```sh
mise exec -- kubectl run dns-check \
  --image=busybox:1.37.0 \
  --restart=Never \
  --command -- sh -c \
  'nslookup kubernetes.default.svc.cluster.local'
mise exec -- kubectl wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/dns-check \
  --timeout=120s
mise exec -- kubectl logs dns-check
```

Actual supplied output:

```text
pod/dns-check created
pod/dns-check condition met
Server:         172.20.0.10
Address:        172.20.0.10:53

Name:   kubernetes.default.svc.cluster.local
Address: 172.20.0.1
```

The cluster DNS service answered at 172.20.0.10 and resolved the built-in Kubernetes API Service to 172.20.0.1. These Service addresses differ from VPC node/pod addresses. A one-shot pod finishing as Completed/Succeeded is expected, not a readiness failure.

### Proof 3: a test application becomes Ready

Created the workload manifest:

```sh
mkdir -p /workspaces/eks-lab/kubernetes
vim /workspaces/eks-lab/kubernetes/test-app.yaml
```

Full committed contents:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
        - name: nginx
          image: nginx:stable-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 128Mi
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
```

The Deployment runs one NGINX web server. The selector matches its pod label; containerPort describes port 80 but does not expose it publicly. CPU/memory requests reserve scheduling capacity; limits constrain usage. The HTTP readiness probe checks `/` on port 80 after two seconds and every three seconds afterward.

```sh
mise exec -- kubectl apply -f /workspaces/eks-lab/kubernetes/test-app.yaml
mise exec -- kubectl rollout status deployment/test-app --timeout=120s
mise exec -- kubectl get pods -l app=test-app
```

The learner confirmed a successful rollout and a 1/1 Running pod, as expected. Raw rollout output and the generated pod name were not supplied, so they are not invented here. No Service, AWS load balancer, or public ingress was created. The image uses a mutable stable-alpine tag for this lab; a reproducible production release should pin a verified version/digest.

## Completion checklist

| Requirement | Result | Evidence |
| --- | --- | --- |
| Terraform recovery apply | Complete | Learner reported success |
| Nodes register | Proven | Two Ready nodes in private subnet ranges |
| Core system pods | Proven | All eight pods Running and fully ready, zero restarts |
| DNS works | Proven | Successful lookup and actual returned addresses |
| Test workload Ready | Confirmed | Learner confirmed rollout and 1/1 Running result |
| AWS add-on status API | Not separately captured | Pod health evidence is recorded above |
| Live SG rules | Not captured | Configuration choices documented in guide 02 |
| Destroy | Approved; outcome pending | Command provided; no final result yet |
| Post-destroy checks | Pending | Must verify cleanup before claiming resources removed |

## Approved cleanup command

After the learner approved destroying this lab, the following commands were provided for the devcontainer terminal:

```sh
cd /workspaces/eks-lab/terraform
mise exec -- terraform destroy
```

Review the proposed deletions and enter `yes` to confirm this lab’s destruction. The separate Podinfo project and existing AuthentikAdmin role are outside this Terraform state. Preserve state and keep the terminal open. If errors occur, inspect remaining resources rather than deleting state.

**Pending:** record Destroy complete output, then read the remaining state and verify the lab’s EKS cluster, workers, NAT, Elastic IP, and storage are gone. No destroy command was executed by this documentation update. Closing SSH or the container does not stop AWS charges.
