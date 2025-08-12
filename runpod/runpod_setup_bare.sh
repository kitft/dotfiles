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