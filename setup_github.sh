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

# 1) Setup GitHub authentication
echo "Checking GitHub authentication..."

# Check if GitHub CLI exists
if command -v gh &> /dev/null; then
    echo "GitHub CLI found..."
    
    # Always set and export GitHub CLI config directory to persistent location
    export GH_CONFIG_DIR="/workspace/kitf/.config/gh"
    mkdir -p "$GH_CONFIG_DIR"
    
    # Check if already authenticated
    if gh auth status > /dev/null 2>&1; then
        echo "✅ Already authenticated with GitHub CLI!"
    else
        echo "Not authenticated with GitHub CLI. Setting up..."
        read -p "Would you like to authenticate with GitHub CLI? (y/n) " setup_gh_cli
        if [[ "$setup_gh_cli" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            gh auth login
            
            if gh auth status > /dev/null 2>&1; then
                echo "✅ Successfully authenticated with GitHub!"
            else
                echo "❌ GitHub authentication failed."
            fi
        fi
    fi
    
    # Configure GitHub CLI to use SSH
    gh config set git_protocol ssh
fi

# Handle SSH keys
mkdir -p "$PERSISTENT_SSH_DIR"
mkdir -p "$HOME_SSH_DIR"

PERSISTENT_KEY_PATH="$PERSISTENT_SSH_DIR/id_ed25519"
HOME_KEY_PATH="$HOME_SSH_DIR/id_ed25519"

# Check if key exists in persistent location
if [ -f "$PERSISTENT_KEY_PATH" ]; then
    echo "✅ Found existing SSH key in $PERSISTENT_SSH_DIR"
    # Copy to home if needed
    if [ ! -f "$HOME_KEY_PATH" ]; then
        echo "Copying SSH keys to $HOME_SSH_DIR..."
        cp "$PERSISTENT_KEY_PATH" "$HOME_KEY_PATH"
        cp "$PERSISTENT_KEY_PATH.pub" "$HOME_KEY_PATH.pub"
        chmod 600 "$HOME_KEY_PATH"
        chmod 644 "$HOME_KEY_PATH.pub"
    fi
elif [ -f "$HOME_KEY_PATH" ]; then
    echo "✅ Found existing SSH key in $HOME_SSH_DIR"
    # Copy to persistent location if needed
    if [ ! -f "$PERSISTENT_KEY_PATH" ]; then
        echo "Backing up SSH keys to $PERSISTENT_SSH_DIR..."
        cp "$HOME_KEY_PATH" "$PERSISTENT_KEY_PATH"
        cp "$HOME_KEY_PATH.pub" "$PERSISTENT_KEY_PATH.pub"
        chmod 600 "$PERSISTENT_KEY_PATH"
        chmod 644 "$PERSISTENT_KEY_PATH.pub"
    fi
else
    # No SSH key exists - ask if user wants to create one
    echo "No SSH key found."
    read -p "Would you like to generate a new SSH key? (y/n) " generate_ssh
    if [[ "$generate_ssh" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Generating new SSH key..."
        ssh-keygen -t ed25519 -C "$email" -f "$PERSISTENT_KEY_PATH" -N ""
        
        # Copy to home directory
        cp "$PERSISTENT_KEY_PATH" "$HOME_KEY_PATH"
        cp "$PERSISTENT_KEY_PATH.pub" "$HOME_KEY_PATH.pub"
        chmod 600 "$HOME_KEY_PATH"
        chmod 644 "$HOME_KEY_PATH.pub"
        chmod 600 "$PERSISTENT_KEY_PATH"
        chmod 644 "$PERSISTENT_KEY_PATH.pub"
        
        echo "Your NEW SSH public key:"
        cat "$PERSISTENT_KEY_PATH.pub"
        read -p "Have you added the SSH key to https://github.com/settings/keys? (y/Y/yes to continue): " response
        while [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; do
            read -p "Please type 'y', 'Y', or 'yes' after adding the SSH key: " response
        done
    fi
fi

# Start SSH agent and add key if it exists
if [ -f "$HOME_KEY_PATH" ]; then
    eval "$(ssh-agent -s)"
    ssh-add "$HOME_KEY_PATH"
    
    # Test SSH connection to GitHub
    echo "Testing SSH connection to GitHub..."
    ssh -T git@github.com -o StrictHostKeyChecking=no || true
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

echo "Setup complete!"

##!/bin/bash
## Input arguments
#email=${1:-"kitfrasertaliente@gmail.com"}
#name=${2:-"Kit FT"}
#github_url=${3:-""}
#
## 0) Setup git
#git config --global user.email "$email"
#git config --global user.name "$name"
#
## 1) Setup SSH key
#echo "Setting up GitHub..."
#read -p "Would you like to set up GitHub credentials? (y/n) " setup_github
#if [[ "$setup_github" =~ ^([yY][eE][sS]|[yY])$ ]]; then
#    # Generate SSH key if it doesn't exist
#    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
#    if [ ! -f "$SSH_KEY_PATH" ]; then
#        ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY_PATH"
#    fi
#
#    # Display the public key
#    echo "Your SSH public key:"
#    cat "$SSH_KEY_PATH.pub"
#
#    read -p "Have you added the SSH key to https://github.com/settings/keys? (y/Y/yes to continue): " response
#    while [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; do
#        read -p "Please type 'y', 'Y', or 'yes' after adding the SSH key: " response
#    done
#
#    # Test SSH connection to GitHub
#    ssh -T git@github.com -o StrictHostKeyChecking=no || true
#
#    # Configure GitHub CLI to use SSH if available
#    if command -v gh &> /dev/null; then
#        echo "GitHub CLI found, configuring to use SSH authentication..."
#        gh config set git_protocol ssh
#        echo "GitHub CLI configured to use SSH. You can verify later with 'gh auth status'"
#    fi
#fi
#
## 2) Project specific setup (if github_url is provided)
#if [ -n "$github_url" ]; then
#    git clone "$github_url"
#    repo_name=$(basename "$github_url" .git)
#    cd "$repo_name"
#    if command -v uv &> /dev/null; then
#        uv pip install -r requirements.txt
#    else
#        pip install -r requirements.txt
#    fi
#fi
#
#echo "Setup complete!
#
#
##!/bin/bash
#
## Input arguments
#email=${1:-"kitfrasertaliente@gmail.com"}
#name=${2:-"Kit FT"}
#github_url=${3:-""}
#
## 0) Setup git
#git config --global user.email "$email"
#git config --global user.name "$name"
#
## 1) Setup SSH key
#ssh-keygen -t ed25519 -C "$email"
#cat /root/.ssh/id_ed25519.pub
#read -p "Have you added the SSH key to https://github.com/settings/keys? (y/Y/yes to continue): " response
#while [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; do
#    read -p "Please type 'y', 'Y', or 'yes' after adding the SSH key: " response
#done
#
## 2) Project specific setup (if github_url is provided)
#if [ -n "$github_url" ]; then
#    git clone "$github_url"
#    repo_name=$(basename "$github_url" .git)
#    cd "$repo_name"
#    uv pip install -r requirements.txt
#fi
#
#
## Configure GitHub CLI to use SSH instead of HTTPS
#if command -v gh &> /dev/null; then
#    echo "GitHub CLI found, configuring to use SSH authentication..."
#    gh config set git_protocol ssh
#    # Test authentication using existing SSH key
#    echo "Testing GitHub CLI with SSH authentication..."
#    gh auth status
#else
#    echo "GitHub CLI not found. Install it with 'apt install gh' or equivalent for your system."
#fi

