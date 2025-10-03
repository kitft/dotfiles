#!/bin/bash

# Hyperbolic Node Setup Script for VeRL Multi-Node Training
# Usage: curl -s https://raw.githubusercontent.com/kitft/dotfiles/main/hyperbolic/hyperbolic_setup.sh -o setup.sh && chmod +x setup.sh && ./setup.sh [head|worker] [storage-vip]

set -e

NODE_TYPE="${1:-worker}"  # Default to worker if not specified
STORAGE_VIP="${2:-}"      # Network volume VIP (optional)

echo "=========================================="
echo "Hyperbolic Node Setup - ${NODE_TYPE} node"
echo "=========================================="

# 1) Setup Linux dependencies
echo "Installing Linux dependencies..."
apt update
apt-get install -y sudo lvm2 nfs-common tmux vim
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

# 2) Setup local scratch volume (LVM-backed NVMe)
echo "Setting up local scratch volume..."
if ! mountpoint -q /workspace; then
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
        sudo mkdir -p /workspace
        if ! grep -q "/dev/mapper/vg0-lv_scratch" /etc/fstab; then
            echo '/dev/mapper/vg0-lv_scratch /workspace ext4 defaults 0 0' | sudo tee -a /etc/fstab
        fi
        sudo mount -a
        echo "✓ Local scratch volume mounted at /workspace"
    else
        echo "⚠ No additional NVMe devices found, using /workspace without LVM"
        sudo mkdir -p /workspace
    fi
else
    echo "✓ /workspace already mounted"
fi

# 3) Setup shared network volume (if VIP provided)
if [ -n "$STORAGE_VIP" ]; then
    echo "Setting up network volume at $STORAGE_VIP..."
    if ! mountpoint -q /data; then
        sudo mkdir -p /data
        if ! grep -q "$STORAGE_VIP:/data" /etc/fstab; then
            echo "$STORAGE_VIP:/data /data nfs rw,nconnect=16,nfsvers=3 0 0" | sudo tee -a /etc/fstab
        fi
        sudo mount -a
        echo "✓ Network volume mounted at /data"
    else
        echo "✓ /data already mounted"
    fi
else
    echo "⚠ No storage VIP provided, skipping network volume setup"
fi

# 4) Setup Python tools
echo "Setting up Python tools..."
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env
uv python install 3.10
sudo uv pip install --system simple-gpu-scheduler
sudo uv pip install --system -U hf_transfer huggingface_hub[cli]

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
cd /workspace/kitf
if [ ! -d "nla" ]; then
    echo "Cloning nla repository..."
    git clone --recurse-submodules https://github.com/kitft/nla
fi

cd nla/verl
git checkout main
git pull

# Create virtual environment on local scratch (each node needs its own compiled extensions)
echo "Creating Python virtual environment..."
rm -rf .venv
python3.10 -m venv .venv
source .venv/bin/activate

# Configure UV to use local cache
export UV_CACHE_DIR=/workspace/.uv_cache
mkdir -p $UV_CACHE_DIR

pip install --upgrade pip

if [ -f "requirements.txt" ]; then
    echo "Installing VeRL dependencies (this may take 10-15 minutes)..."
    pip install -r requirements.txt
    pip install flash-attn==2.8.2 --no-build-isolation
    pip install --no-deps sgl_kernel==0.2.4
    echo "✓ VeRL environment installed"
else
    echo "⚠ requirements.txt not found, skipping VeRL installation"
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
cat > /workspace/kitf/.cluster_env << 'EOF'
# Hyperbolic Cluster Environment Variables
# Source this file in your training scripts or shell: source /workspace/kitf/.cluster_env

# Storage paths
export DATA_DIR=/data                          # Shared NFS storage for datasets and checkpoints
export WORKSPACE_DIR=/workspace/kitf           # Local scratch for code and venvs
export VERL_DIR=/workspace/kitf/nla/verl      # VeRL installation directory

# Python environment
export VENV_PATH=/workspace/kitf/nla/verl/.venv

# Hugging Face
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_HOME=/workspace/.cache/huggingface   # Local cache on fast NVMe

# Example usage in your training script:
# DATA_PATH = os.environ.get('DATA_DIR', '/data')
# CHECKPOINT_PATH = f"{DATA_PATH}/checkpoints/my_model"
# DATASET_PATH = f"{DATA_PATH}/datasets/my_dataset"
EOF

echo "✓ Created cluster environment file at /workspace/kitf/.cluster_env"

# 14) Node-specific setup
if [ "$NODE_TYPE" == "head" ]; then
    echo ""
    echo "=========================================="
    echo "HEAD NODE SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "STORAGE PATHS:"
    echo "  • Shared data/checkpoints: /data"
    echo "  • Local code/venvs:        /workspace/kitf"
    echo "  • VeRL directory:          /workspace/kitf/nla/verl"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Start Ray head:"
    echo "     ray start --head --port=6379 --dashboard-port=8265"
    echo ""
    echo "  2. Note the Ray address shown (share with worker nodes)"
    echo ""
    echo "  3. In your training script, use these paths:"
    echo "     • Datasets:     /data/datasets/"
    echo "     • Checkpoints:  /data/checkpoints/"
    echo ""
    echo "  4. Run training:"
    echo "     cd /workspace/kitf/nla/verl"
    echo "     source .venv/bin/activate"
    echo "     python your_training_script.py"
    echo ""
    echo "TIP: Source cluster env for convenience:"
    echo "     source /workspace/kitf/.cluster_env"
else
    echo ""
    echo "=========================================="
    echo "WORKER NODE SETUP COMPLETE"
    echo "=========================================="
    echo ""
    echo "STORAGE PATHS:"
    echo "  • Shared data/checkpoints: /data"
    echo "  • Local code/venvs:        /workspace/kitf"
    echo "  • VeRL directory:          /workspace/kitf/nla/verl"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Get Ray head address from head node"
    echo ""
    echo "  2. Start Ray worker:"
    echo "     ray start --address=<head-ip>:6379"
    echo ""
    echo "TIP: Source cluster env for convenience:"
    echo "     source /workspace/kitf/.cluster_env"
fi

echo ""
echo "=========================================="

./deploy.sh --vim
