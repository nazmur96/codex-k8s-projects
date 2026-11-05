# Development environment and authentication

## Development environment

Docker runs the container; DevPod creates it and provides SSH access. The devcontainer defines Ubuntu userland, and mise installs the declared project tools inside it. A graphical editor is optional.

| Tool | Pinned version |
| --- | --- |
| Terraform | 1.17.1 |
| AWS CLI | 2.39.3 |
| kubectl | 1.37.2 |

EKS Kubernetes 1.37 was subsequently selected from the regional AWS version listing, matching kubectl 1.37.2.

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

On the **host**, enter the project directory and create the tool configuration:

```sh
cd ~/orca/projects/codex-k8s-projects
vim mise.toml
```

In Vim, press `i`, paste the following, then press Escape, type `:wq`, and press Enter to save and exit.

Full contents of [mise.toml](https://github.com/nazmur96/codex-k8s-projects/blob/main/mise.toml):

```toml
[tools]
terraform = "1.17.1"
aws-cli = "2.39.3"
kubectl = "1.37.2"
```

`[tools]` declares the tool list. Terraform manages AWS infrastructure, AWS CLI handles login and AWS API commands, and kubectl communicates with Kubernetes. Explicit versions keep tool selection consistent between environments.

Create the container configuration directory and file:

```sh
mkdir -p .devcontainer
vim .devcontainer/devcontainer.json
```

Full current contents of [devcontainer.json](https://github.com/nazmur96/codex-k8s-projects/blob/main/.devcontainer/devcontainer.json):

```json
{
  "name": "EKS Terraform Lab",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers-extra/features/mise:1": {}
  },
  "mounts": [
    "source=${localEnv:HOME}/.aws,target=/home/vscode/.aws,type=bind"
  ],
  "postCreateCommand": "mise trust && mise install",
  "remoteUser": "vscode"
}
```

| Setting | Purpose |
| --- | --- |
| `name` | Human-readable development environment name. |
| `image` | Ubuntu base image containing the container userland. The `ubuntu` tag is mutable; it does not pin an exact image digest. |
| `features` | Adds mise to the image. `:1` selects the feature's major version. |
| `mounts` | Shares the host's existing AWS directory with the container. `${localEnv:HOME}` resolves to the host user's home. This setting was added after our first launch; see step 4. |
| `postCreateCommand` | Trusts our mise configuration and installs its tools after container creation. |
| `remoteUser` | Runs our development session as the regular Linux user `vscode`. |

Save and exit Vim as above. The container runs:

```sh
mise trust && mise install
```

That command runs **inside the container** during creation. Running `mise exec` on the host can automatically install missing tools on the host; avoid doing that for this project.

A host warning such as `mise WARN missing: terraform@...` is expected when the tools are installed only inside the container. It does not mean the container setup failed. Do not run a host installation just to clear that warning.

### 3. Start and enter the container

From the project directory on the **host**:

```sh
devpod up . --id eks-lab --provider docker --ide none
ssh eks-lab.devpod
```

We also tried the following **host** command, which launched Cursor:

```sh
devpod up . --id eks-lab --provider docker --ide cursor
```

An editor window opening does not prove its terminal is inside the container. The initial Cursor terminal returned `Outside Docker`. We attempted Cursor's **Connect via SSH** flow using `eks-lab.devpod`; its folder picker started in `/home/vscode`. The project path is `/workspaces/eks-lab`, not the host path or `/workspaces/codex-k8s-projects`. Completing the Cursor connection was not verified. SSH from an Orca terminal was verified and is our working terminal workflow.

Inside the **container**:

```sh
test -f /.dockerenv && echo "Inside Docker" || echo "Outside Docker"
pwd
mise exec -- terraform version
mise exec -- aws --version
mise exec -- kubectl version --client
```

Verified project path: `/workspaces/eks-lab`. Keep one host terminal and one container terminal open. `exit` leaves the SSH session without stopping the container.

Expected version checks returned Terraform `1.17.1`, AWS CLI `2.39.3`, and kubectl client `1.37.2`.

The prompt `vscode ➜ /workspaces/eks-lab (main) $` shows the container username, directory, and Git branch. The host prompt shows `orca/projects/codex-k8s-projects`. Use the host terminal for Docker/DevPod management and the container terminal for Terraform/AWS/kubectl. No repeated SSH login is needed while that container terminal remains connected.

Useful **host** inspection commands:

```sh
devpod provider list
devpod list
docker ps
```

### 4. Share the existing AWS configuration

Initially, this command returned no profiles inside the container:

```sh
mise exec -- aws configure list-profiles
```

We checked the host configuration with these **host** commands:

```sh
ls -ld ~/.aws
ls -l ~/.aws/config
```

Running them inside the container before adding the mount reported `/home/vscode/.aws` missing. That was the container's home directory, not evidence that the host configuration was absent.

The host profile listing confirmed the required profiles existed. During troubleshooting, running `mise exec -- aws configure list-profiles` on the host unintentionally installed the project's tool versions there. Those exact host installations were subsequently removed:

```sh
# Host only: this cleanup was already completed.
mise uninstall terraform@1.17.1 aws-cli@2.39.3 kubectl@1.37.2 --yes
```

Older versions used by other projects were preserved. The container's three tools were checked again and still worked.

We added this bind mount to the devcontainer configuration:

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

That initial command was:

```sh
mise exec -- aws login --profile authentik --region eu-central-1
```

For this host-browser/container-terminal setup, use the `--remote` command above instead.

Verify the CLI session:

```sh
mise exec -- aws sts get-caller-identity --profile authentik --region eu-central-1
```

The expected Authentik-backed account and role were confirmed. Do not commit login URLs, authorization codes, tokens, or session caches.

**Terraform profile check, subsequently confirmed by the learner:**

```sh
mise exec -- aws sts get-caller-identity --profile authentik-tf --region eu-central-1
```

Both profile identity checks were confirmed against the intended account. Our AWS provider explicitly sets `profile = "authentik-tf"`. `AWS_PROFILE=authentik-tf` is also the environment-variable convention used for this profile; backend authentication is separate from provider configuration.


### Session expiry

The session expired during the EKS version lookup. Repeating the remote login under `authentik`, completing browser approval, and retrying the command under `authentik-tf` restored access. Saved Terraform files were unaffected.
