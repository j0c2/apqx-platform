# Self-Hosted GitHub Actions Runner

This directory contains a **minimal, ephemeral self-hosted runner** using Docker Compose. This satisfies the stretch goal requirement for a self-hosted CI runner without adding complexity to the Kubernetes cluster.

## 🎯 Design Goals

- **One-command setup**: Simple `make runner-up` / `make runner-down`  
- **Ephemeral**: Runner auto-unregisters when stopped (no lingering registrations)
- **Secure**: Uses scoped Personal Access Token, no long-lived credentials  
- **Minimal**: Pure Docker Compose, no additional controllers or CRDs
- **Local**: Runs on your laptop/VM, not in the cluster

## 🚀 Quick Start

### 1. Create GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with these scopes:
   - `repo` (full control of private repositories)  
   - `workflow` (update GitHub Action workflows)
3. Copy the token (starts with `ghp_...`)

### 2. Configure Environment

```bash
# The .env file was created from template - edit it:
vim runner/.env

# Replace GITHUB_TOKEN with your actual token:
GITHUB_TOKEN=ghp_your_actual_token_here
```

### 3. Start Runner

```bash
make runner-up
```

### 4. Verify Registration  

Visit your repo → **Settings** → **Actions** → **Runners**  
You should see `local-runner-1` with status **Online**.

### 5. Test CI Pipeline

Push to main branch - the **build** job should now run on your self-hosted runner!

```bash
git push origin main
# Check Actions tab - build job will show [self-hosted, linux, x64]
```

## 🛠 Management Commands

```bash
# Start runner
make runner-up

# Check status  
make runner-status

# Stop runner (auto-unregisters)
make runner-down
```

## 📋 Runner Configuration

| Setting | Value | Purpose |
|---------|--------|---------|
| **EPHEMERAL** | `"1"` | Auto-unregister when stopped |
| **RUNNER_WORKDIR** | `/tmp/runner` | Temporary work directory |  
| **Docker Socket** | `/var/run/docker.sock` | Enable Docker builds |
| **Labels** | `self-hosted,linux,x64` | CI job targeting |

## 🔒 Security Features  

- **Scoped PAT**: Only repo + workflow permissions
- **Ephemeral registration**: No persistent runner state
- **Container isolation**: Runner runs in isolated container
- **No cluster access**: Completely separate from k8s infrastructure

## 🎯 CI Integration

Only the **build** job uses the self-hosted runner:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64]  # Uses your runner
    
  test:
    runs-on: ubuntu-latest             # Uses GitHub hosted
```

This provides the stretch goal demonstration while keeping the pipeline resilient (other jobs still work if your runner is down).

## 🔧 Troubleshooting

**Runner shows offline in GitHub:**
```bash
make runner-down
make runner-up
# Check Docker logs: docker logs actions-runner
```

**Build job fails:**
```bash  
# Ensure Docker is available to runner
make runner-status
docker logs actions-runner
```

**Token issues:**
```bash
# Verify token has correct scopes
# Regenerate PAT if needed
```

## 🧹 Cleanup

```bash
# Stop and remove runner
make runner-down

# Remove environment file
rm runner/.env
```

The runner is **fully reversible** and leaves no traces when stopped.