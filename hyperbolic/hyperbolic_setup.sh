#!/bin/bash

# Hyperbolic Node Setup Script for VeRL Multi-Node Training
# Usage: curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/hyperbolic_setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh [head|worker] [storage-vip]

set -e

NODE_TYPE="${1:-worker}"  # Default to worker if not specified
STORAGE_VIP="${2:-}"      # Network volume VIP (optional)

echo "=========================================="
echo "Hyperbolic Node Setup - ${NODE_TYPE} node"
echo "=========================================="

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    echo "Installing sudo..."
    apt update && apt-get install -y sudo
fi

# 1) Setup Linux dependencies
echo "Installing Linux dependencies..."
sudo apt-get update && DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
    sudo \
    less \
    nano \
    htop \
    ncdu \
    nvtop \
    lsof \
    zsh \
    tmux \
    neovim \
    gh \
    lvm2 \
    nfs-common

# 2) Setup shared network volume (if VIP provided) - mount to /workspace
if [ -n "$STORAGE_VIP" ]; then
    echo "Setting up shared network volume at $STORAGE_VIP..."
    if ! mountpoint -q /workspace; then
        sudo mkdir -p /workspace

        # Test if NFS server is reachable
        echo "Testing NFS server connectivity..."
        if ! showmount -e "$STORAGE_VIP" 2>/dev/null; then
            echo "⚠ WARNING: Cannot connect to NFS server at $STORAGE_VIP"
            echo "  This usually means:"
            echo "    1. The network volume hasn't been created/attached in Hyperbolic UI yet"
            echo "    2. The VIP address is incorrect"
            echo "    3. The NFS server is still starting up (wait 30 seconds and retry)"
            echo ""
            echo "  Please create/attach the network volume in Hyperbolic UI first, then re-run:"
            echo "    sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 $STORAGE_VIP:/data /workspace"
            echo ""
            echo "  Continuing with rest of setup..."
        else
            # Add to fstab if not already there
            if ! grep -q "$STORAGE_VIP" /etc/fstab; then
                echo "$STORAGE_VIP:/data /workspace nfs rw,nconnect=16,nfsvers=3 0 0" | sudo tee -a /etc/fstab
            fi

            # Try to mount
            echo "Mounting shared network volume to /workspace..."
            if sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 "$STORAGE_VIP:/data" /workspace; then
                echo "✓ Shared network volume mounted at /workspace"
                # Fix ownership so current user can write
                sudo chown -R $USER:$USER /workspace
            else
                echo "⚠ Failed to mount network volume"
                echo "  Debug: Check dmesg or /var/log/syslog for errors"
                echo "  Try manually: sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 $STORAGE_VIP:/data /workspace"
            fi
        fi
    else
        echo "✓ /workspace already mounted"
    fi

    # Always ensure current user has write permissions to /workspace
    if [ ! -w /workspace ]; then
        echo "Fixing /workspace permissions..."
        sudo chown -R $USER:$USER /workspace
    fi
else
    echo "⚠ No storage VIP provided, skipping network volume setup"
    echo "  Note: You'll need to mount /workspace manually for shared storage features"
fi

# 3) Setup local scratch volume (LVM-backed NVMe) - mount to /scratch
echo "Setting up local scratch volume..."
if ! mountpoint -q /scratch; then
    # Detect NVMe devices (skip nvme0n1 and nvme1n1, use nvme2n1+)
    NVME_DEVICES=$(lsblk -d -o name,type | grep nvme | awk '{print "/dev/"$1}' | grep -E 'nvme[2-9]n1')

    if [ -n "$NVME_DEVICES" ]; then
        echo "Found NVMe devices: $NVME_DEVICES"

        # Create volume group if it doesn't exist
        if ! sudo vgs vg0 &>/dev/null; then
            sudo vgcreate vg0 $NVME_DEVICES
        fi

        # Create logical volume if it doesn't exist
        if ! sudo lvs vg0/lv_scratch &>/dev/null; then
            sudo lvcreate -n lv_scratch -l 100%FREE vg0
            sudo mkfs.ext4 /dev/mapper/vg0-lv_scratch
        fi

        # Mount the volume
        sudo mkdir -p /scratch
        if ! grep -q "/dev/mapper/vg0-lv_scratch" /etc/fstab; then
            echo '/dev/mapper/vg0-lv_scratch /scratch ext4 defaults 0 0' | sudo tee -a /etc/fstab
        fi
        sudo mount -a
        echo "✓ Local scratch volume mounted at /scratch"
    else
        echo "⚠ No additional NVMe devices found, creating /scratch without LVM"
        sudo mkdir -p /scratch
    fi
else
    echo "✓ /scratch already mounted"
fi

# Always ensure current user has write permissions to /scratch
if [ ! -w /scratch ]; then
    echo "Fixing /scratch permissions..."
    sudo chown -R $USER:$USER /scratch
fi

# 4) Setup Python tools
echo "Setting up Python tools..."
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env

# Verify uv is in PATH
if ! command -v uv &> /dev/null; then
    echo "⚠ uv not found in PATH after install, adding manually"
    export PATH="$HOME/.local/bin:$PATH"
fi

uv python install 3.10.14

# Install CLI tools to user space (avoids permission issues)
pip3 install --user huggingface_hub[cli] hf_transfer simple-gpu-scheduler

# Ensure user pip bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"

# 5) Setup dotfiles and ZSH
echo "Setting up dotfiles and ZSH..."
mkdir -p /workspace/kitf && cd /workspace/kitf
if [ ! -d "dotfiles" ]; then
    git clone https://github.com/kitft/dotfiles.git
fi
cd dotfiles
./install.sh --zsh --tmux

# Only change shell if not already using zsh
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    echo "Changing shell to zsh..."
    sudo chsh -s /usr/bin/zsh
else
    echo "Already using zsh as default shell."
fi

# 6) Setup GitHub automatically
echo "Setting up GitHub..."

# Export GH_CONFIG_DIR so gh CLI uses shared storage
export GH_CONFIG_DIR="/workspace/kitf/.config/gh"

if [ -f "./setup_github.sh" ]; then
    chmod +x ./setup_github.sh
    ./setup_github.sh
else
    echo "Error: setup_github.sh not found in $(pwd) directory"
    exit 1
fi

cd /workspace/kitf/dotfiles

# 7) Update Node.js to latest version
echo "Installing Node.js..."
sudo apt-get remove -y nodejs || true
sudo dpkg --remove --force-remove-reinstreq libnode-dev || true
curl -fsSL https://deb.nodesource.com/setup_23.x | sudo -E bash -
sudo apt-get install -y nodejs

# 8) Claude Code setup
echo "Installing Claude Code..."
mkdir -p /workspace/kitf/.npm-global
npm config set prefix /workspace/kitf/.npm-global
echo 'export PATH=/workspace/kitf/.npm-global/bin:$PATH' >> ~/.zshrc
export PATH=/workspace/kitf/.npm-global/bin:$PATH
npm install -g @anthropic-ai/claude-code

# 9) Block Ray ports for security
echo "Blocking Ray ports..."
if [ -f "./hyperbolic_block.sh" ]; then
    sudo ./hyperbolic_block.sh
else
    echo "Warning: hyperbolic_block.sh not found"
fi

# 10) Setup secrets and environment variables
echo "Setting up secrets..."
cd /workspace/kitf/dotfiles

# Export GH_CONFIG_DIR so gh CLI works in this session
export GH_CONFIG_DIR="/workspace/kitf/.config/gh"

if [ -f "./setup_env.sh" ]; then
    chmod +x ./setup_env.sh
    ./setup_env.sh

    # Source the .env file to get secrets
    if [ -f "./.env" ]; then
        set -a
        source ./.env
        set +a
        echo "✓ Secrets loaded"
    fi
else
    echo "⚠ setup_env.sh not found, you'll need to set HF_TOKEN and WANDB_API_KEY manually"
fi

# 11) Setup VeRL environment
echo "Setting up VeRL environment..."

# Check if /workspace is mounted
if ! mountpoint -q /workspace; then
    echo "⚠ WARNING: /workspace is not mounted!"
    echo "  Skipping code cloning to shared storage."
    echo "  After mounting /workspace, run:"
    echo "    mkdir -p /workspace/kitf && cd /workspace/kitf"
    echo "    git clone --recurse-submodules git@github.com:kitft/nla.git"
    echo ""
    echo "  Then create the symlink:"
    echo "    cd /workspace/kitf/nla/verl && ln -s /scratch/venvs/nla/.venv .venv"
    echo ""
    SKIP_CODE_SETUP=true
else
    # Clone code to shared storage (if on head node or if doesn't exist)
    if [ ! -d "/workspace/kitf/nla" ]; then
        echo "Cloning nla repository to shared storage..."
        mkdir -p /workspace/kitf
        cd /workspace/kitf
        git clone --recurse-submodules git@github.com:kitft/nla.git
    else
        echo "✓ Code already exists on shared storage"
        cd /workspace/kitf/nla
        git checkout main
        git pull
    fi
    SKIP_CODE_SETUP=false
fi

# Create virtual environment on local scratch (each node needs its own compiled extensions)
echo "Creating Python virtual environment on local scratch..."
mkdir -p /scratch/venvs/nla
cd /scratch/venvs/nla

# Configure UV to use local cache
export UV_CACHE_DIR=/scratch/.uv_cache
mkdir -p $UV_CACHE_DIR

# Install from shared code location (if available)
if [ "$SKIP_CODE_SETUP" = false ] && [ -f "/workspace/kitf/nla/verl/requirements.txt" ]; then
    echo "Installing VeRL dependencies (this may take 10-15 minutes)..."

    # Run installation commands one by one in same zsh session
    /usr/bin/zsh <<'SCRIPT'
        set -e
        [ -f ~/.zshrc ] && source ~/.zshrc
        export UV_CACHE_DIR=/scratch/.uv_cache
        export PATH="$HOME/.local/bin:$PATH"
        cd /scratch/venvs/nla
        rm -rf .venv
        uv venv --python=3.10.14
        source .venv/bin/activate
        cp /workspace/kitf/nla/verl/requirements.txt requirements.txt
        uv pip sync requirements.txt
        uv pip install flash-attn==2.8.2 --no-build-isolation
        pip install --no-deps sgl_kernel==0.2.4
SCRIPT
    echo "✓ VeRL environment installed"

    # Create symlink from shared code to local venv
    echo "Creating symlink from shared code to local venv..."
    if [ -L ".venv" ] || [ -d ".venv" ]; then
        rm -rf .venv
    fi
    ln -s /scratch/venvs/nla/.venv .venv
    echo "✓ Symlink created: /workspace/kitf/nla/verl/.venv -> /scratch/venvs/nla/.venv"
else
    echo "⚠ Skipping VeRL installation (no shared storage available)"
    echo "  Install dependencies manually after mounting /workspace"
fi

# 12) Login to HF and W&B if tokens are available
if [ -n "$HF_TOKEN" ]; then
    export HF_HUB_ENABLE_HF_TRANSFER=1
    huggingface-cli login --token $HF_TOKEN
    echo "✓ Logged into Hugging Face"
else
    echo "⚠ HF_TOKEN not set, skipping Hugging Face login"
fi

if [ -n "$WANDB_API_KEY" ]; then
    wandb login --relogin $WANDB_API_KEY
    echo "✓ Logged into Weights & Biases"
else
    echo "⚠ WANDB_API_KEY not set, skipping W&B login"
fi

# 13) Create helpful environment file
cat > /scratch/.cluster_env << 'EOF'
# Hyperbolic Cluster Environment Variables
# Source this file in your training scripts or shell: source /scratch/.cluster_env

# Storage paths
export WORKSPACE_DIR=/workspace                       # Shared NFS storage (code, datasets, checkpoints)
export CODE_DIR=/workspace/kitf/nla                   # Shared code repository
export VERL_DIR=/workspace/kitf/nla/verl             # VeRL directory (shared code)
export SCRATCH_DIR=/scratch                           # Local scratch (venvs, caches)
export VENV_DIR=/scratch/venvs/nla/.venv             # Local venv (per-node compiled extensions)

# Python environment (symlink in shared code points to local venv)
export VENV_PATH=/workspace/kitf/nla/verl/.venv      # Use this - it's a symlink to local venv

# Hugging Face
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_HOME=/scratch/.cache/huggingface           # Local cache on fast NVMe

# Example usage in your training script:
# CHECKPOINT_PATH = "/workspace/checkpoints/my_model"
# DATASET_PATH = "/workspace/datasets/my_dataset"
EOF

echo "✓ Created cluster environment file at /scratch/.cluster_env"

# 14) Node-specific setup
if [ "$NODE_TYPE" == "head" ]; then
    echo ""
    echo "=========================================="
    echo "HEAD NODE SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "STORAGE PATHS:"
    echo "  • Shared workspace:        /workspace (NFS - code, datasets, checkpoints)"
    echo "  • Shared code:             /workspace/kitf/nla (all nodes see same code)"
    echo "  • Local scratch:           /scratch (NVMe - venvs, caches)"
    echo "  • Local venvs:             /scratch/venvs/nla/.venv (per-node)"
    echo "  • Symlink:                 /workspace/kitf/nla/verl/.venv -> /scratch/venvs/nla/.venv"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Start Ray head:"
    echo "     ray start --head --port=6379 --dashboard-port=8265"
    echo ""
    echo "  2. Note the Ray address shown (share with worker nodes)"
    echo ""
    echo "  3. In your training script, use these paths:"
    echo "     • Datasets:     /workspace/datasets/"
    echo "     • Checkpoints:  /workspace/checkpoints/"
    echo ""
    echo "  4. Run training:"
    echo "     cd /workspace/kitf/nla/verl"
    echo "     source .venv/bin/activate    # follows symlink to local venv"
    echo "     python your_training_script.py"
    echo ""
    echo "TIP: Source cluster env for convenience:"
    echo "     source /scratch/.cluster_env"
else
    echo ""
    echo "=========================================="
    echo "WORKER NODE SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "STORAGE PATHS:"
    echo "  • Shared workspace:        /workspace (NFS - code, datasets, checkpoints)"
    echo "  • Shared code:             /workspace/kitf/nla (all nodes see same code)"
    echo "  • Local scratch:           /scratch (NVMe - venvs, caches)"
    echo "  • Local venvs:             /scratch/venvs/nla/.venv (per-node)"
    echo "  • Symlink:                 /workspace/kitf/nla/verl/.venv -> /scratch/venvs/nla/.venv"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Get Ray head address from head node"
    echo ""
    echo "  2. Start Ray worker:"
    echo "     ray start --address=<head-ip>:6379"
    echo ""
    echo "TIP: Source cluster env for convenience:"
    echo "     source /scratch/.cluster_env"
fi

echo ""
echo "=========================================="

./deploy.sh --vim
