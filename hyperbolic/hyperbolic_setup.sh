#!/bin/bash

# Hyperbolic Node Setup Script for VeRL Multi-Node Training
# Usage: curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/hyperbolic_setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh [head|worker] [storage-vip]

set -e

NODE_TYPE="${1:-worker}"  # Default to worker if not specified
STORAGE_VIP="${2:-}"      # Network volume VIP (optional)

# Track skipped steps for final summary
SKIP_WARNINGS=()

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
            SKIP_WARNINGS+=("/workspace mount failed - NFS server $STORAGE_VIP unreachable. Create/attach network volume in Hyperbolic UI first.")
        else
            # Add to fstab if not already there
            if ! grep -q "$STORAGE_VIP" /etc/fstab; then
                echo "$STORAGE_VIP:/data /workspace nfs rw,nconnect=16,nfsvers=3 0 0" | sudo tee -a /etc/fstab
            fi

            # Try to mount
            echo "Mounting shared network volume to /workspace..."
            if sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 "$STORAGE_VIP:/data" /workspace; then
                echo "✓ Shared network volume mounted at /workspace"
                # Ensure user directory exists
                mkdir -p /workspace/kitf
                # Verify we can write to it
                if ! touch /workspace/kitf/.write_test 2>/dev/null; then
                    echo "⚠ WARNING: Cannot write to /workspace/kitf - check NFS export permissions"
                    SKIP_WARNINGS+=("/workspace/kitf not writable - check NFS export settings")
                else
                    rm /workspace/kitf/.write_test
                    echo "✓ /workspace/kitf is writable"
                fi
            else
                echo "⚠ Failed to mount network volume"
                echo "  Debug: Check dmesg or /var/log/syslog for errors"
                echo "  Try manually: sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 $STORAGE_VIP:/data /workspace"
                SKIP_WARNINGS+=("/workspace mount failed - try manually: sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 $STORAGE_VIP:/data /workspace")
            fi
        fi
    else
        echo "✓ /workspace already mounted"
    fi

    # Always verify user directory is writable
    mkdir -p /workspace/kitf
    if ! touch /workspace/kitf/.write_test 2>/dev/null; then
        echo "⚠ WARNING: Cannot write to /workspace/kitf"
        SKIP_WARNINGS+=("/workspace/kitf not writable - check permissions")
    else
        rm /workspace/kitf/.write_test
    fi
else
    echo "⚠ No storage VIP provided, skipping network volume setup"
    echo "  Note: You'll need to mount /workspace manually for shared storage features"
    SKIP_WARNINGS+=("/workspace not mounted - no storage VIP provided. Mount manually: sudo mount -t nfs -o rw,nconnect=16,nfsvers=3 <VIP>:/data /workspace")
fi

# 3) Setup local scratch volume (LVM-backed NVMe) - mount to /scratch
echo "Setting up local scratch volume..."
if ! mountpoint -q /scratch; then
    # Create volume group if it doesn't exist
    if ! sudo vgs vg0 &>/dev/null; then
        echo "Creating LVM volume group from NVMe devices..."
        sudo vgcreate vg0 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1 /dev/nvme5n1 /dev/nvme6n1
    else
        echo "✓ Volume group vg0 already exists"
    fi

    # Create logical volume if it doesn't exist
    if ! sudo lvs vg0/lv_scratch &>/dev/null; then
        echo "Creating logical volume..."
        sudo lvcreate -n lv_scratch -l 100%FREE vg0
        sudo mkfs.ext4 /dev/mapper/vg0-lv_scratch
    else
        echo "✓ Logical volume lv_scratch already exists"
    fi

    # Add to fstab if not already there
    sudo mkdir -p /scratch
    if ! grep -q "/dev/mapper/vg0-lv_scratch" /etc/fstab; then
        echo "Adding /scratch to /etc/fstab..."
        echo '/dev/mapper/vg0-lv_scratch /scratch ext4 defaults 0 0' | sudo tee -a /etc/fstab
    fi

    # Mount the volume
    echo "Mounting /scratch..."
    sudo mount -v /scratch
    sudo df -hPT /scratch
    echo "✓ Local scratch volume mounted at /scratch"
else
    echo "✓ /scratch already mounted"
    sudo df -hPT /scratch
fi

# Verify /scratch is writable
if ! touch /scratch/.write_test 2>/dev/null; then
    echo "⚠ WARNING: Cannot write to /scratch"
    echo "Attempting to fix permissions..."
    sudo chown $USER:$USER /scratch
else
    rm /scratch/.write_test
fi

# Setup cache directories on /scratch
echo "Configuring cache directories on /scratch..."
export UV_CACHE_DIR=/scratch/.uv_cache
export HF_HOME=/scratch/.cache/huggingface
mkdir -p $UV_CACHE_DIR $HF_HOME

# Add to shell rc files for persistence
echo 'export UV_CACHE_DIR=/scratch/.uv_cache' >> ~/.bashrc
echo 'export HF_HOME=/scratch/.cache/huggingface' >> ~/.bashrc
echo 'export UV_CACHE_DIR=/scratch/.uv_cache' >> ~/.zshrc
echo 'export HF_HOME=/scratch/.cache/huggingface' >> ~/.zshrc
echo "✓ Cache directories configured: UV_CACHE_DIR=$UV_CACHE_DIR, HF_HOME=$HF_HOME"

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
if [ -f "./hyperbolic/hyperbolic_block_localhost_only.sh" ]; then
    sudo ./hyperbolic/hyperbolic_block_localhost_only.sh
else
    echo "Warning: hyperbolic/hyperbolic_block_localhost_only.sh not found"
    echo "  Falling back to basic block script..."
    if [ -f "./hyperbolic/hyperbolic_block.sh" ]; then
        sudo ./hyperbolic/hyperbolic_block.sh
    else
        echo "  ERROR: No firewall script found!"
        SKIP_WARNINGS+=("Ray port firewall not configured - run hyperbolic_block_localhost_only.sh manually")
    fi
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
    SKIP_WARNINGS+=("setup_env.sh not found - set HF_TOKEN and WANDB_API_KEY manually")
fi

# 11) Setup VeRL environment
echo "Setting up VeRL environment..."

# Check if /workspace is mounted
if ! mountpoint -q /workspace; then
    echo "⚠ WARNING: /workspace is not mounted!"
    echo "  Skipping code cloning to shared storage."
    echo "  After mounting /workspace, run:"
    echo "    mkdir -p /workspace/kitf && cd /workspace/kitf"
    echo "    git clone --recurse-submodules https://github.com/kitft/nla.git"
    echo ""
    echo "  Then create the symlink:"
    echo "    cd /workspace/kitf/nla && ln -s /scratch/venvs/nla/.venv .venv"
    echo ""
    SKIP_CODE_SETUP=true
    SKIP_WARNINGS+=("Code cloning skipped - /workspace not mounted. Clone manually after mounting /workspace.")
else
    # Clone code to shared storage (if on head node or if doesn't exist)
    # Check if it's a valid git repo (not just an empty directory)
    if [ ! -d "/workspace/kitf/nla/.git" ]; then
        echo "Cloning nla repository to shared storage..."
        mkdir -p /workspace/kitf
        cd /workspace/kitf
        # Use HTTPS clone (works with gh CLI auth, no SSH keys needed)
        git clone --recurse-submodules https://github.com/kitft/nla.git
    else
        echo "✓ Code already exists on shared storage"
        cd /workspace/kitf/nla
        # Ensure remote uses HTTPS (in case it was cloned with SSH before)
        git remote set-url origin https://github.com/kitft/nla.git
        git checkout main
        git pull
    fi
    SKIP_CODE_SETUP=false
fi

# Create virtual environment on local scratch (each node needs its own compiled extensions)
echo "Creating Python virtual environment on local scratch..."
mkdir -p /scratch/venvs/nla
cd /scratch/venvs/nla

# Note: VeRL environment installation must be done manually
echo ""
echo "=========================================="
echo "⚠️  MANUAL STEP REQUIRED"
echo "=========================================="
echo ""
echo "To complete VeRL installation, run:"
echo "  cd /workspace/kitf/nla"
echo "  /workspace/kitf/dotfiles/hyperbolic/install_env.sh"
echo ""
echo "This will:"
echo "  - Create venv in /scratch/venvs/nla/.venv"
echo "  - Install all dependencies including flash-attn"
echo "  - Create symlink from code to venv"
echo ""

# 12) Login to HF and W&B if tokens are available
if [ -n "$HF_TOKEN" ]; then
    export HF_HUB_ENABLE_HF_TRANSFER=1
    huggingface-cli login --token $HF_TOKEN
    echo "✓ Logged into Hugging Face"
else
    echo "⚠ HF_TOKEN not set, skipping Hugging Face login"
    SKIP_WARNINGS+=("Hugging Face login skipped - HF_TOKEN not set. Login manually: huggingface-cli login")
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
export VENV_PATH=/workspace/kitf/nla/.venv           # Use this - it's a symlink to local venv

# Cache directories (use fast local NVMe for caching)
export UV_CACHE_DIR=/scratch/.uv_cache               # UV/pip cache
export HF_HOME=/scratch/.cache/huggingface           # Hugging Face cache
export HF_HUB_ENABLE_HF_TRANSFER=1                   # Fast HF downloads

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

    # Print any warnings/skipped steps
    if [ ${#SKIP_WARNINGS[@]} -gt 0 ]; then
        echo "⚠️  WARNINGS - STEPS THAT WERE SKIPPED:"
        echo ""
        for warning in "${SKIP_WARNINGS[@]}"; do
            echo "  • $warning"
        done
        echo ""
        echo "=========================================="
        echo ""
    fi

    echo "STORAGE PATHS:"
    echo "  • Shared workspace:        /workspace (NFS - code, datasets, checkpoints)"
    echo "  • Shared code:             /workspace/kitf/nla (all nodes see same code)"
    echo "  • Local scratch:           /scratch (NVMe - venvs, caches)"
    echo "  • Local venvs:             /scratch/venvs/nla/.venv (per-node)"
    echo "  • Symlink:                 /workspace/kitf/nla/.venv -> /scratch/venvs/nla/.venv"
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
    echo "     cd /workspace/kitf/nla"
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

    # Print any warnings/skipped steps
    if [ ${#SKIP_WARNINGS[@]} -gt 0 ]; then
        echo "⚠️  WARNINGS - STEPS THAT WERE SKIPPED:"
        echo ""
        for warning in "${SKIP_WARNINGS[@]}"; do
            echo "  • $warning"
        done
        echo ""
        echo "=========================================="
        echo ""
    fi

    echo "STORAGE PATHS:"
    echo "  • Shared workspace:        /workspace (NFS - code, datasets, checkpoints)"
    echo "  • Shared code:             /workspace/kitf/nla (all nodes see same code)"
    echo "  • Local scratch:           /scratch (NVMe - venvs, caches)"
    echo "  • Local venvs:             /scratch/venvs/nla/.venv (per-node)"
    echo "  • Symlink:                 /workspace/kitf/nla/.venv -> /scratch/venvs/nla/.venv"
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

cd /workspace/kitf/dotfiles
chmod +x hyperbolic/install_env.sh
./deploy.sh --vim
