#!/bin/bash
set -euo pipefail
USAGE=$(cat <<-END
    Usage: ./deploy.sh [OPTIONS] [--aliases <alias1,alias2,...>], eg. ./deploy.sh --vim --aliases=speechmatics,custom
    Creates ~/.zshrc and ~/.tmux.conf with location
    specific config

    OPTIONS:
        --vim                   deploy very simple vimrc config 
        --aliases               specify additional alias scripts to source in .zshrc, separated by commas
	--secrets           get your secrets from Github secrets
END
)

export DOT_DIR=$(dirname $(realpath $0))

VIM="false"
SECRETS="false"
ALIASES=()
while (( "$#" )); do
    case "$1" in
        -h|--help)
            echo "$USAGE" && exit 1 ;;
        --vim)
            VIM="true" && shift ;;
	--secrets)
	    SECRETS="true"&& shift ;;
        --aliases=*)
            IFS=',' read -r -a ALIASES <<< "${1#*=}" && shift ;;
        --) # end argument parsing
            shift && break ;;
        -*|--*=) # unsupported flags
            echo "Error: Unsupported flag $1" >&2 && exit 1 ;;
    esac
done

echo "deploying on machine..."
if [ ${#ALIASES[@]} -eq 0 ]; then
    echo "No extra aliases specified."
else
    echo "using extra aliases: ${ALIASES[*]}"
fi

# Tmux setup
echo "source $DOT_DIR/config/tmux.conf" > $HOME/.tmux.conf

# Vimrc
if [[ $VIM == "true" ]]; then
    echo "deploying .vimrc"
    echo "source $DOT_DIR/config/vimrc" > $HOME/.vimrc
fi

# zshrc setup
echo "source $DOT_DIR/config/zshrc.sh" > $HOME/.zshrc
# Append additional alias scripts if specified
if [ -n "${ALIASES+x}" ]; then
    for alias in "${ALIASES[@]}"; do
        echo "source $DOT_DIR/config/aliases_${alias}.sh" >> $HOME/.zshrc
    done
fi


if [[ $SECRETS == "true" ]]; then
	echo "getting secrets"
	source "$DOT_DIR/setup_env.sh"
fi

# Check if the current shell is already zsh
if [[ "$SHELL" == *"zsh"* ]]; then
    echo "Your shell is already set to zsh: $SHELL"
else
    echo "Current shell is: $SHELL"
    echo "Changing default shell to zsh..."

    # Check if zsh is installed
    if command -v zsh &> /dev/null; then
        ZSH_PATH=$(which zsh)
        echo "zsh found at: $ZSH_PATH"

        # Check if zsh is in /etc/shells
        if grep -q "$ZSH_PATH" /etc/shells; then
            sudo chsh -s "$ZSH_PATH" "$USER"
            echo "Shell changed to zsh. Please log out and log back in for changes to take effect."
        else
            echo "Error: $ZSH_PATH is not in /etc/shells"
            echo "Adding zsh to /etc/shells first..."
            echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
            sudo chsh -s "$ZSH_PATH" "$USER"
            echo "Shell changed to zsh. Please log out and log back in for changes to take effect."
        fi
    else
        echo "zsh is not installed. Please install zsh first."
        echo "You can install it with: sudo apt install zsh (Debian/Ubuntu)"
        echo "or: sudo yum install zsh (CentOS/RHEL)"
        echo "or: brew install zsh (macOS with Homebrew)"
    fi
fi

zsh
