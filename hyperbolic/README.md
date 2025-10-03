# Hyperbolic Multi-Node Setup

Quick setup scripts for Hyperbolic VeRL training clusters.

## Quick Start

### Head Node

```bash
curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/quick_init.sh | bash -s -- head <storage-vip>
```

### Worker Node

```bash
curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/quick_init.sh | bash -s -- worker <storage-vip>
```

Replace `<storage-vip>` with your Hyperbolic network volume's virtual IP address.

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

### Local Scratch (`/workspace`) - Node-Specific
- **Code repositories** (`/workspace/kitf/nla`)
- **Python venvs** (`.venv` with compiled CUDA kernels)
- **UV cache** (`/workspace/.uv_cache`)
- **Dotfiles** (`/workspace/kitf/dotfiles`)
- **Secrets** (`.env` files)

**Why local?** Each node needs its own compiled extensions (flash-attn, CUDA kernels) that are hardware-specific. Sharing these would cause conflicts.

### Network Volume (`/data`) - Shared
- **Datasets** (training data accessible to all nodes)
- **Model checkpoints** (saved/loaded by all nodes)
- **Shared configs** (if needed)

**Why shared?** All nodes need to access the same training data and save/load checkpoints to a common location.

## Architecture

- **Head node**: Coordinates Ray cluster, runs training script
- **Worker nodes**: Execute rollouts and optimization
- **Local scratch** (`/workspace`): LVM-backed NVMe, fast local storage for code/venvs
- **Network volume** (`/data`): NFS-mounted shared storage for datasets/checkpoints

## Security

All nodes automatically block incoming traffic on Ray ports using iptables. This is critical for Hyperbolic's multi-tenant environment.
