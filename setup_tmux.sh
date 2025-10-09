setup_tmux() {
  echo "Setting up tmux configuration..."

  # Save current directory to return later
  local original_dir=$(pwd)

  # Try to find the dotfiles directory and cd into it
  local dotfiles_dir=""
  if [ -d "/workspace/kitf/dotfiles" ]; then
    dotfiles_dir="/workspace/kitf/dotfiles"
  elif [ -d "$HOME/dotfiles" ]; then
    dotfiles_dir="$HOME/dotfiles"
  elif [ -d "$(dirname $(realpath ${BASH_SOURCE[0]:-$0}))" ]; then
    dotfiles_dir="$(dirname $(realpath ${BASH_SOURCE[0]:-$0}))"
  fi

  # If we found dotfiles dir, cd into it
  if [ -n "$dotfiles_dir" ]; then
    cd "$dotfiles_dir"
  fi

  # Determine config source - try multiple locations
  if [ -f "./config/tmux.conf" ]; then
    CONFIG_SOURCE="./config/tmux.conf"
  elif [ -f "./tmux.conf" ]; then
    CONFIG_SOURCE="./tmux.conf"
  elif [ -f "/workspace/kitf/dotfiles/config/tmux.conf" ]; then
    CONFIG_SOURCE="/workspace/kitf/dotfiles/config/tmux.conf"
  elif [ -f "/workspace/kitf/dotfiles/tmux.conf" ]; then
    CONFIG_SOURCE="/workspace/kitf/dotfiles/tmux.conf"
  elif [ -f "$HOME/dotfiles/config/tmux.conf" ]; then
    CONFIG_SOURCE="$HOME/dotfiles/config/tmux.conf"
  elif [ -f "$HOME/dotfiles/tmux.conf" ]; then
    CONFIG_SOURCE="$HOME/dotfiles/tmux.conf"
  else
    echo "Warning: tmux config file not found in expected locations"
    cd "$original_dir"
    return 1
  fi

  # Copy tmux configuration
  cp "$CONFIG_SOURCE" ~/.tmux.conf
  echo "Copied tmux config from $CONFIG_SOURCE"

  # Install TPM (Tmux Plugin Manager)
  mkdir -p ~/.tmux/plugins
  if [ ! -d ~/.tmux/plugins/tpm ]; then
    echo "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi

  # Install plugins with checks
  install_plugin() {
    local plugin_name=$1
    local plugin_url=$2

    if [ ! -d ~/.tmux/plugins/$plugin_name ]; then
      echo "Installing plugin: $plugin_name"
      mkdir -p ~/.tmux/plugins/$plugin_name
      git clone $plugin_url ~/.tmux/plugins/$plugin_name
    fi
  }

  install_plugin "tmux-resurrect" "https://github.com/tmux-plugins/tmux-resurrect"
  install_plugin "tmux-continuum" "https://github.com/tmux-plugins/tmux-continuum"
  install_plugin "tmux-sensible" "https://github.com/tmux-plugins/tmux-sensible"

  # Source the tmux configuration if tmux is running
  if [ -n "$TMUX" ]; then
    tmux source-file ~/.tmux.conf
  fi

  # Return to original directory
  cd "$original_dir"

  echo "tmux configuration complete!"
}

# Execute the function
setup_tmux
