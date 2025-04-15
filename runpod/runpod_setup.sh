#!/bin/bash

# 2) Setup linux dependencies
echo "Installing Linux dependencies..."
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
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
sudo apt update
#sudo apt install gh
sudo apt-get install gh

# 3) Setup Python tools
echo "Setting up Python tools..."
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env
uv python install 3.11
uv pip install simple-gpu-scheduler

# 4) Setup dotfiles and ZSH
echo "Setting up dotfiles and ZSH..."
mkdir -p /workspace/kitf/git && cd /workspace/kitf/git
git clone https://github.com/kitft/dotfiles.git
cd dotfiles
./install.sh --zsh --tmux
chsh -s /usr/bin/zsh

# 5)
echo "Setting up GitHub... in $(echo pwd)"
read -p "Would you like to set up GitHub credentials with setup_github.sh? (y/n) " setup_github
if [[ $setup_github =~ ^[Yy]$ ]]; then
    cd "$(dirname "$0")"
    if [ -f "./setup_github.sh" ]; then
        chmod +x ./setup_github.sh
        ./setup_github.sh
    else
        echo "Error: setup_github.sh not found in $(dirname "$0") directory"
        exit 1
    fi
fi



# update nodejs/claude code


# Update Node.js to latest version
sudo apt-get remove -y nodejs
sudo dpkg --remove --force-remove-reinstreq libnode-dev
curl -fsSL https://deb.nodesource.com/setup_23.x | sudo -E bash -
sudo apt-get install -y nodejs

# Claude code
npm install -g @anthropic-ai/claude-code
alias workspace="cd /workspace/kitf"

./deploy.sh --vim # Note: This starts a new shell, ending this script
