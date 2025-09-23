# Self-Hosted GitHub Actions Runner (Native)

This directory contains a **native GitHub Actions self-hosted runner**. This satisfies the stretch goal requirement for a self-hosted CI runner without adding complexity to the Kubernetes cluster.

## 🎯 Design Goals

- **Native performance**: Runs directly on macOS without containerization overhead
- **Simple management**: `make runner-config` / `make runner-up` / `make runner-down` / `make runner-status`
- **Secure**: Uses scoped Personal Access Token for authentication
- **Configurable**: Standard GitHub runner with local configuration
- **Local**: Runs on your laptop/VM, not in the cluster

## 🚀 Quick Start

### 1. Create GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with these scopes:
   - `repo` (full control of private repositories)  
   - `workflow` (update GitHub Action workflows)
3. Copy the token (starts with `ghp_...`)

### 2. Configure Runner (One-time Setup)

```bash
# Option 1: Use Makefile helper for instructions
make runner-config

# Option 2: Manual configuration
cd runner
./config.sh --url https://github.com/j0c2/apqx-platform --token YOUR_PAT
# Follow prompts (press Enter for defaults)
```

### 3. Start Runner

```bash
make runner-up
```

### 4. Verify Registration  

Visit your repo → **Settings** → **Actions** → **Runners**  
You should see `self-hosted-runner` with status **Online**.

### 5. Test CI Pipeline

Push to main branch - the **build** job should now run on your self-hosted runner!

```bash
git push origin main
# Check Actions tab - build job will show [self-hosted, macOS, X64]
```

## 🛠 Management Commands

```bash
# One-time setup
make runner-config      # Show configuration instructions

# Daily operations
make runner-up           # Start runner
make runner-status       # Check status  
make runner-down         # Stop runner

# Manual operations (if needed)
cd runner
./run.sh                 # Start manually
./config.sh remove       # Unregister runner
```

## 📋 Runner Configuration

| Setting | Value | Purpose |
|---------|--------|---------|
| **Agent Name** | `self-hosted-runner` | Identifier in GitHub UI |
| **Repository** | `j0c2/apqx-platform` | Target repository |
| **Labels** | `self-hosted,macOS,X64` | CI job targeting |
| **Work Directory** | `_work` | Job workspace |

## 🔒 Security Features  

- **Scoped PAT**: Only repo + workflow permissions required
- **Local execution**: No container or network exposure
- **Standard runner**: Uses official GitHub Actions runner binary
- **Process isolation**: Runs as local user processes

## 🎯 CI Integration

Only the **build** job uses the self-hosted runner:

```yaml
jobs:
  build:
    runs-on: [self-hosted, macOS, X64]  # Uses your runner
    
  test:
    runs-on: ubuntu-latest             # Uses GitHub hosted
```

This provides the stretch goal demonstration while keeping the pipeline resilient (other jobs still work if your runner is down).

## 🔧 Troubleshooting

**Runner shows offline in GitHub:**
```bash
make runner-status
make runner-down
make runner-up
# Check logs: tail -f runner/runner.log
```

**Build job fails:**
```bash  
# Check runner logs
tail -f runner/runner.log

# Check runner process
make runner-status
ps aux | grep Runner.Listener
```

**Configuration issues:**
```bash
# Remove and reconfigure
cd runner
./config.sh remove
make runner-config
# Follow instructions to reconfigure
```

## 🧹 Cleanup

```bash
# Stop runner
make runner-down

# Remove registration (one-time)
cd runner && ./config.sh remove

# Clean work directory
rm -rf runner/_work/*
```

## 📁 Directory Contents

- `actions-runner-osx-x64-2.328.0.tar.gz` - Downloaded runner package
- `bin/` - Runner binaries and dependencies
- `config.sh` - Configuration script
- `run.sh` - Start runner script  
- `svc.sh` - Service management script
- `.runner` - Runner configuration (auto-generated)
- `.credentials*` - Authentication files (auto-generated)
- `_work/` - Job workspace (auto-generated)
- `_diag/` - Diagnostic logs (auto-generated)

The runner provides **native macOS performance** and is fully reversible when configuration is removed.

## ⚡ Performance Benefits

- **No container overhead**: Direct process execution
- **Native file system**: No volume mounting delays
- **Local Docker**: Direct Docker daemon access
- **Full system access**: Native macOS tools and environments
- **Faster builds**: Local caching and no network overhead for basic operations