#!/bin/bash
# Input arguments
email=${1:-"kitfrasertaliente@gmail.com"}
name=${2:-"Kit FT"}
github_url=${3:-""}

# Define persistent SSH directory for RunPod
PERSISTENT_SSH_DIR="/workspace/kitf/.ssh"
HOME_SSH_DIR="$HOME/.ssh"

echo "Current user: $(whoami)"
echo "HOME directory: $HOME"

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

    if [ -f "/workspace/kitf/dotfiles/config/zshrc.sh" ]; then
        if ! grep -q "export GH_CONFIG_DIR=" "/workspace/kitf/dotfiles/config/zshrc.sh"; then
            echo 'export GH_CONFIG_DIR="/workspace/kitf/.config/gh"' >> "/workspace/kitf/dotfiles/config/zshrc.sh"
        fi
    fi
    
    echo "ℹ️  Added GH_CONFIG_DIR to shell configs."
    echo "ℹ️  To use gh in this session, run: export GH_CONFIG_DIR=\"/workspace/kitf/.config/gh\""
fi

# 0) Setup git
git config --global user.email "$email"
git config --global user.name "$name"

# 1) Setup GitHub CLI authentication FIRST
echo "Setting up GitHub CLI authentication..."
if command -v gh &> /dev/null; then
    mkdir -p "$GH_CONFIG_DIR"

    # Check if auth exists in persistent storage
    if [ -f "$GH_CONFIG_DIR/hosts.yml" ]; then
        echo "✅ Found existing GitHub CLI auth in persistent storage"
    fi

    # Check if actually authenticated
    GH_STATUS_OUTPUT=$(gh auth status 2>&1 || true)

    if echo "$GH_STATUS_OUTPUT" | grep -q "Logged in"; then
        echo "✅ Already authenticated with GitHub CLI!"
    else
        # If auth file exists but not valid, remove it
        if [ -f "$GH_CONFIG_DIR/hosts.yml" ]; then
            echo "⚠️  Auth file exists but is invalid, removing..."
            rm -f "$GH_CONFIG_DIR/hosts.yml"
        fi

        # Try to authenticate with token if GITHUB_TOKEN is set
        if [ -n "$GITHUB_TOKEN" ]; then
            echo "🔐 Authenticating with GITHUB_TOKEN..."
            echo "$GITHUB_TOKEN" | gh auth login --with-token
            if gh auth status 2>&1 | grep -q "Logged in"; then
                echo "✅ Successfully authenticated with token!"
            fi
        else
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📱 GitHub CLI Authentication Required"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "To use 'gh' CLI for accessing private repos, authenticate now:"
            echo ""
            echo "  1. Copy the one-time code that will be shown"
            echo "  2. Open: https://github.com/login/device"
            echo "  3. Paste the code and authorize"
            echo ""
            echo "Press ENTER to continue (or Ctrl+C to skip gh auth)..."
            read -r

            if gh auth login --web 2>&1; then
                if gh auth status 2>&1 | grep -q "Logged in"; then
                    echo "✅ Successfully authenticated with GitHub!"
                else
                    echo "⚠️  Authentication may have failed, continuing..."
                fi
            fi

            echo ""
            echo "Note: SSH keys will work for git operations even without gh CLI auth"
        fi
    fi

    # Configure GitHub CLI to use HTTPS (works without SSH keys)
    gh config set git_protocol https 2>/dev/null || true
else
    echo "❌ GitHub CLI not found. Please install it first."
fi

# 2) Handle SSH keys
mkdir -p "$PERSISTENT_SSH_DIR"
mkdir -p "$HOME_SSH_DIR"

PERSISTENT_KEY_PATH="$PERSISTENT_SSH_DIR/id_ed25519"
HOME_KEY_PATH="$HOME_SSH_DIR/id_ed25519"
ROOT_KEY_PATH="/root/.ssh/id_ed25519"

echo "Checking for SSH keys in:"
echo "  - Persistent: $PERSISTENT_SSH_DIR"
echo "  - Home: $HOME_SSH_DIR"
echo "  - Root: /root/.ssh"

# Check all possible locations for existing keys
key_found=false
if [ -f "$PERSISTENT_KEY_PATH" ]; then
    echo "✅ Found existing SSH key in persistent storage"
    if [ ! -f "$HOME_KEY_PATH" ]; then
        cp "$PERSISTENT_KEY_PATH" "$HOME_KEY_PATH"
        cp "$PERSISTENT_KEY_PATH.pub" "$HOME_KEY_PATH.pub"
        chmod 600 "$HOME_KEY_PATH"
        chmod 644 "$HOME_KEY_PATH.pub"
    fi
    key_found=true
elif [ -f "$HOME_KEY_PATH" ]; then
    echo "✅ Found existing SSH key in home directory"
    if [ ! -f "$PERSISTENT_KEY_PATH" ] && [ -d "/workspace/kitf" ]; then
        cp "$HOME_KEY_PATH" "$PERSISTENT_KEY_PATH"
        cp "$HOME_KEY_PATH.pub" "$PERSISTENT_KEY_PATH.pub"
        chmod 600 "$PERSISTENT_KEY_PATH"
        chmod 644 "$PERSISTENT_KEY_PATH.pub"
    fi
    key_found=true
elif [ -f "$ROOT_KEY_PATH" ] && [ "$HOME" != "/root" ]; then
    echo "✅ Found existing SSH key in /root/.ssh"
    # Copy from root to persistent and home
    cp "$ROOT_KEY_PATH" "$HOME_KEY_PATH"
    cp "$ROOT_KEY_PATH.pub" "$HOME_KEY_PATH.pub"
    chmod 600 "$HOME_KEY_PATH"
    chmod 644 "$HOME_KEY_PATH.pub"
    
    if [ -d "/workspace/kitf" ]; then
        cp "$ROOT_KEY_PATH" "$PERSISTENT_KEY_PATH"
        cp "$ROOT_KEY_PATH.pub" "$PERSISTENT_KEY_PATH.pub"
        chmod 600 "$PERSISTENT_KEY_PATH"
        chmod 644 "$PERSISTENT_KEY_PATH.pub"
    fi
    key_found=true
fi

# If no key found, create one automatically
if [ "$key_found" = false ]; then
    echo "No SSH key found. Creating new SSH key for GitHub..."
    
    # Generate key in persistent location if available, otherwise in home
    if [ -d "/workspace/kitf" ]; then
        target_key="$PERSISTENT_KEY_PATH"
    else
        target_key="$HOME_KEY_PATH"
    fi
    
    ssh-keygen -t ed25519 -C "$email" -f "$target_key" -N ""
    
    # Copy to both locations
    if [ "$target_key" = "$PERSISTENT_KEY_PATH" ] && [ ! -f "$HOME_KEY_PATH" ]; then
        cp "$PERSISTENT_KEY_PATH" "$HOME_KEY_PATH"
        cp "$PERSISTENT_KEY_PATH.pub" "$HOME_KEY_PATH.pub"
        chmod 600 "$HOME_KEY_PATH"
        chmod 644 "$HOME_KEY_PATH.pub"
    elif [ "$target_key" = "$HOME_KEY_PATH" ] && [ -d "/workspace/kitf" ]; then
        cp "$HOME_KEY_PATH" "$PERSISTENT_KEY_PATH"
        cp "$HOME_KEY_PATH.pub" "$PERSISTENT_KEY_PATH.pub"
        chmod 600 "$PERSISTENT_KEY_PATH"
        chmod 644 "$PERSISTENT_KEY_PATH.pub"
    fi
    
    echo "📋 Your NEW SSH public key:"
    cat "${target_key}.pub"
    echo ""
    echo "⚠️  Add this key to https://github.com/settings/keys"
    echo "Press Enter when you've added the key to GitHub..."
    read -r
fi

# Start SSH agent and add key if it exists
if [ -f "$HOME_KEY_PATH" ]; then
    eval "$(ssh-agent -s)"
    ssh-add "$HOME_KEY_PATH"
    
    # Test connection
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


echo "Configuring git to use gh CLI for credentials"
git config --global credential.helper ""
git config --global credential.https://github.com.helper "!gh auth git-credential"

echo "GitHub setup complete!"
if [ -d "/workspace/kitf" ]; then
    echo ""
    echo "⚠️  IMPORTANT: To use GitHub CLI in this session, run:"
    echo "    export GH_CONFIG_DIR=\"/workspace/kitf/.config/gh\""
    echo "Or start a new shell session for the changes to take effect."
    export GH_CONFIG_DIR="/workspace/kitf/.config/gh"
fi

