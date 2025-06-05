#!/bin/bash
# Input arguments
email=${1:-"kitfrasertaliente@gmail.com"}
name=${2:-"Kit FT"}
github_url=${3:-""}

# Define persistent SSH directory for RunPod
PERSISTENT_SSH_DIR="/workspace/kitf/.ssh"
HOME_SSH_DIR="$HOME/.ssh"

# Check if running in RunPod environment
if [ -d "/workspace/kitf" ]; then
    echo "📁 RunPod environment detected. Using persistent storage at /workspace/kitf/"
    
    # Add GH_CONFIG_DIR to shell configs for persistence
    export GH_CONFIG_DIR="/workspace/kitf/.config/gh"
    
    # Add to .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "export GH_CONFIG_DIR=" "$HOME/.bashrc"; then
            echo 'export GH_CONFIG_DIR="/workspace/kitf/.config/gh"' >> "$HOME/.bashrc"
        fi
    fi
    
    # Add to .zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "export GH_CONFIG_DIR=" "$HOME/.zshrc"; then
            echo 'export GH_CONFIG_DIR="/workspace/kitf/.config/gh"' >> "$HOME/.zshrc"
        fi
    fi
fi

# 0) Setup git
git config --global user.email "$email"
git config --global user.name "$name"

# 1) Check for existing credentials
echo "Checking GitHub authentication..."

# Check if GitHub CLI exists and is authenticated
if command -v gh &> /dev/null; then
    export GH_CONFIG_DIR="/workspace/kitf/.config/gh"
    mkdir -p "$GH_CONFIG_DIR"
    
    if gh auth status > /dev/null 2>&1; then
        echo "✅ Already authenticated with GitHub CLI!"
        gh config set git_protocol ssh
    else
        echo "GitHub CLI not authenticated. Please authenticate manually if needed."
    fi
fi

# Handle SSH keys
mkdir -p "$PERSISTENT_SSH_DIR"
mkdir -p "$HOME_SSH_DIR"

PERSISTENT_KEY_PATH="$PERSISTENT_SSH_DIR/id_ed25519"
HOME_KEY_PATH="$HOME_SSH_DIR/id_ed25519"

# Check if key exists and copy between locations
if [ -f "$PERSISTENT_KEY_PATH" ]; then
    echo "✅ Found existing SSH key in persistent storage"
    if [ ! -f "$HOME_KEY_PATH" ]; then
        cp "$PERSISTENT_KEY_PATH" "$HOME_KEY_PATH"
        cp "$PERSISTENT_KEY_PATH.pub" "$HOME_KEY_PATH.pub"
        chmod 600 "$HOME_KEY_PATH"
        chmod 644 "$HOME_KEY_PATH.pub"
    fi
elif [ -f "$HOME_KEY_PATH" ]; then
    echo "✅ Found existing SSH key in home directory"
    if [ ! -f "$PERSISTENT_KEY_PATH" ] && [ -d "/workspace/kitf" ]; then
        cp "$HOME_KEY_PATH" "$PERSISTENT_KEY_PATH"
        cp "$HOME_KEY_PATH.pub" "$PERSISTENT_KEY_PATH.pub"
        chmod 600 "$PERSISTENT_KEY_PATH"
        chmod 644 "$PERSISTENT_KEY_PATH.pub"
    fi
else
    echo "No SSH key found. Run this script manually to set up GitHub credentials."
fi

# Start SSH agent and add key if it exists
if [ -f "$HOME_KEY_PATH" ]; then
    eval "$(ssh-agent -s)"
    ssh-add "$HOME_KEY_PATH"
fi

# 2) Project specific setup (if github_url is provided)
if [ -n "$github_url" ]; then
    # If authenticated with GitHub CLI, use it for cloning
    if command -v gh &> /dev/null && gh auth status > /dev/null 2>&1; then
        repo_name=$(basename "$github_url" .git)
        org_repo=${github_url#*github.com/}
        org_repo=${org_repo%.git}

        echo "Cloning $org_repo using GitHub CLI..."
        gh repo clone "$org_repo" || git clone "$github_url"
    else
        git clone "$github_url"
    fi

    repo_name=$(basename "$github_url" .git)
    if [ -d "$repo_name" ]; then
        cd "$repo_name"
        if [ -f "requirements.txt" ]; then
            echo "Installing requirements..."
            if command -v uv &> /dev/null; then
                uv pip install -r requirements.txt
            else
                pip install -r requirements.txt
            fi
        else
            echo "No requirements.txt found."
        fi
    else
        echo "Failed to clone repository."
    fi
fi

echo "setting credential store"
git config --global credential.helper store

echo "GitHub setup complete!"
