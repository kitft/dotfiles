# Hyperbolic Multi-Node Setup

Quick setup scripts for Hyperbolic VeRL training clusters.

## Quick Start

**IMPORTANT:** Run as your normal user (NOT with sudo). The script will use `sudo` internally where needed.

### Head Node

```bash
curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/quick_init.sh | bash -s -- head <storage-vip>
```

### Worker Node

```bash
curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/quick_init.sh | bash -s -- worker <storage-vip>
```

Replace `<storage-vip>` with your Hyperbolic network volume's virtual IP address.

If you need to install sudo first (on minimal images):
```bash
apt update && apt install -y sudo
# Then add your user to sudoers or run the script
```

## What Gets Installed

- **System packages**: LVM, NFS, tmux, vim, zsh, neovim, gh, monitoring tools
- **Storage**:
  - Local scratch volume at `/workspace` (LVM-backed NVMe aggregation)
  - Network volume at `/data` (NFS-mounted shared storage)
- **Python**: Python 3.10 via uv, Hugging Face CLI, hf_transfer
- **Dotfiles**: Your personal dotfiles, ZSH config, tmux setup
- **Node.js**: Latest version (v23.x) + Claude Code
- **Security**: iptables rules blocking Ray ports (6379, 8265, 10001, worker ports)
- **VeRL**: Virtual environment with dependencies (requires manual repo clone)

## What Happens Automatically

The script handles everything automatically:
- ✓ Clones your dotfiles and nla repository
- ✓ Pulls secrets from `kitft/secrets` repo via `setup_env.sh`
- ✓ Logs into Hugging Face and Weights & Biases
- ✓ Installs all VeRL dependencies (including flash-attn, sgl_kernel)
- ✓ Blocks Ray ports with iptables

## Manual Steps

After setup completes:

1. **Start Ray cluster**:

   On **head node**:
   ```bash
   ray start --head --port=6379 --dashboard-port=8265
   # Note the Ray address shown
   ```

   On **worker nodes**:
   ```bash
   ray start --address=<head-node-ip>:6379
   ```

2. **Run training**:
   ```bash
   cd /workspace/kitf/nla/verl
   source .venv/bin/activate
   python your_training_script.py
   ```

## Storage Strategy

### Shared NFS (`/data`) - Accessible to All Nodes
- **Code repository** (`/data/code/nla`) - Clone once, all nodes see same code
- **Datasets** (`/data/datasets/`) - Training data accessible to all nodes
- **Model checkpoints** (`/data/checkpoints/`) - Saved/loaded by all nodes
- **Symlink** (`/data/code/nla/verl/.venv` → `/workspace/venvs/nla/.venv`) - Points to local venv

### Local Scratch (`/workspace`) - Node-Specific
- **Python venvs** (`/workspace/venvs/nla/.venv`) - Compiled CUDA kernels per node
- **UV cache** (`/workspace/.uv_cache`)
- **Dotfiles** (`/workspace/kitf/dotfiles`)
- **HF cache** (`/workspace/.cache/huggingface`)

### How It Works

The clever part: code lives on shared storage, but each node has its own venv with compiled extensions on local scratch. A symlink in the shared code directory points to each node's local venv:

```
/data/code/nla/verl/.venv  →  /workspace/venvs/nla/.venv
```

Since the symlink path is identical on all nodes, each node follows it to its own local venv. This means:
- ✓ Clone code once, use everywhere
- ✓ Edit code once, all nodes see changes
- ✓ Each node has its own compiled extensions (no conflicts)
- ✓ Standard workflow: `cd /data/code/nla/verl && source .venv/bin/activate`

## Architecture

- **Head node**: Coordinates Ray cluster, runs training script
- **Worker nodes**: Execute rollouts and optimization
- **Local scratch** (`/workspace`): LVM-backed NVMe, fast local storage for venvs/caches
- **Network volume** (`/data`): NFS-mounted shared storage for code/datasets/checkpoints

## Security

All nodes automatically block incoming traffic on Ray ports using iptables. This is critical for Hyperbolic's multi-tenant environment.
