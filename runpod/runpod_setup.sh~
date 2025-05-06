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
sudo apt-get update
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
mkdir -p /workspace/kitf && cd /workspace/kitf
git clone https://github.com/kitft/dotfiles.git
cd dotfiles
./install.sh --zsh --tmux

# Only change shell if not already using zsh
if [ "$SHELL" != "/usr/bin/zsh" ]; then
  echo "Changing shell to zsh..."
  chsh -s /usr/bin/zsh
else
  echo "Already using zsh as default shell."
fi

# 5)
echo "Setting up GitHub... in $(pwd)"
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

# Include the setup_tmux function
source "./setup_tmux.sh"
# Or directly include the function definition in your RunPod script

# Claude code
npm install -g @anthropic-ai/claude-code
alias workspace="cd /workspace/kitf"

./deploy.sh --vim # Note: This starts a new shell, ending this script

