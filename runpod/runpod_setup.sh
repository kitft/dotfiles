#!/bin/bash

# 2) Setup linux dependencies
echo "Installing Linux dependencies..."
apt update
apt-get install sudo
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
    gh

# 3) Setup Python tools
echo "Setting up Python tools..."
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env
uv python install 3.11
sudo uv pip install --system simple-gpu-scheduler
sudo uv pip install --system -U hf_transfer

# 4) Setup dotfiles and ZSH
echo "Setting up dotfiles and ZSH..."
mkdir -p /workspace/kitf && cd /workspace/kitf
git clone https://github.com/kitft/dotfiles.git
cd dotfiles
./install.sh --zsh --tmux

# Only change shell if not already using zsh
if [ "$SHELL" != "/usr/bin/zsh" ]; then
  echo "Changing shell to zsh..."
  sudo chsh -s /usr/bin/zsh
else
  echo "Already using zsh as default shell."
fi

# 5) Setup GitHub automatically
echo "Setting up GitHub..."
if [ -f "./setup_github.sh" ]; then
    chmod +x ./setup_github.sh
    ./setup_github.sh
else
    echo "Error: setup_github.sh not found in $(pwd) directory"
    exit 1
fi

cd /workspace/kitf/dotfiles

# update nodejs/claude code


# Update Node.js to latest version
sudo apt-get remove -y nodejs
sudo dpkg --remove --force-remove-reinstreq libnode-dev
curl -fsSL https://deb.nodesource.com/setup_23.x | sudo -E bash -
sudo apt-get install -y nodejs

# Include the setup_tmux function
source "./setup_tmux.sh"
# Or directly include the function definition in your RunPod script

# Claude code
# Configure npm to use a user-writable directory
mkdir -p /workspace/kitf/.npm-global
npm config set prefix /workspace/kitf/.npm-global
echo 'export PATH=/workspace/kitf/.npm-global/bin:$PATH' >> ~/.zshrc
export PATH=/workspace/kitf/.npm-global/bin:$PATH
npm install -g @anthropic-ai/claude-code

alias workspace="cd /workspace/kitf"

# Block Ray ports if on Hyperbolic node
if [ -n "$HYPERBOLIC_NODE" ] || [ -n "$HYPERBOLIC" ] || hostname | grep -iq "hyperbolic"; then
    echo "Detected Hyperbolic node - blocking Ray ports..."
    if [ -f "./hyperbolic_block.sh" ]; then
        sudo ./hyperbolic_block.sh
    else
        echo "Warning: hyperbolic_block.sh not found"
    fi
fi

./deploy.sh --vim # Note: This starts a new shell, ending this script

