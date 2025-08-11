CONFIG_DIR=$(dirname $(realpath ${(%):-%x}))
DOT_DIR=$CONFIG_DIR/..

# Instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export TERM="xterm-256color"

ZSH_DISABLE_COMPFIX=true
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH=$HOME/.oh-my-zsh

plugins=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)

source $ZSH/oh-my-zsh.sh
source $CONFIG_DIR/aliases.sh
source $CONFIG_DIR/p10k.zsh
source $CONFIG_DIR/extras.sh
source $CONFIG_DIR/key_bindings.sh
add_to_path "${DOT_DIR}/custom_bins"

# for uv
#if [ -d "$HOME/.local/bin" ]; then
#  source $HOME/.local/bin/env

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
if [ -d "$HOME/.cargo" ]; then
  . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

if [ -d "$HOME/.local/bin/micromamba" ]; then
  export MAMBA_EXE="$HOME/.local/bin/micromamba"
  export MAMBA_ROOT_PREFIX="$HOME/micromamba"
  __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__mamba_setup"
  else
      alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
  fi
  unset __mamba_setup
fi

FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

if command -v ask-sh &> /dev/null; then
  export ASK_SH_OPENAI_API_KEY=$(cat $HOME/.openai_api_key)
  export ASK_SH_OPENAI_MODEL=gpt-4o-mini
  eval "$(ask-sh --init)"
fi

llmc() {
    local system_prompt='Output a command that I can run in a ZSH terminal on macOS to accomplish the following task. Try to make the command self-documenting, using the long version of flags where possible. Output the command first enclosed in a "```zsh" codeblock followed by a concise explanation of how it accomplishes it.'
    local temp_file=$(mktemp)
    local capturing=true
    local command_buffer=""
    local first_line=true
    local cleaned_up=false # Flag to indicate whether cleanup has been run

    cleanup() {
        # Only run cleanup if it hasn't been done yet
        if [[ "$cleaned_up" == false ]]; then
            cleaned_up=true # Set the flag to prevent duplicate cleanup

            # Check if the temporary file exists before attempting to read from it
            if [[ -f "$temp_file" ]]; then
                while IFS= read -r line; do
                    if [[ "$line" == '```zsh' ]]; then
                        command_buffer=""
                        first_line=true
                    elif [[ "$line" == '```' && "$capturing" == true ]]; then
                        if [[ "$first_line" == true ]]; then
                            echo -n "$command_buffer" | pbcopy
                        else
                            echo -n "${command_buffer//$'\n'/\\n}" | pbcopy
                        fi
                        break
                    elif [[ "$capturing" == true ]]; then
                        if [[ "$first_line" == false ]]; then
                            command_buffer+=$'\n'
                        fi
                        command_buffer+="$line"
                        first_line=false
                    fi
                done <"$temp_file"
            fi

            # Always attempt to remove the temporary file if it exists
            #[[ -f "$temp_file" ]] && rm -f "$temp_file"
	    if [[ -f "$temp_file" ]] && [[ $(find "$temp_file" -type f -mmin -1 | wc -l) -gt 0 ]]; then
		    rm "$temp_file"
	    fi

            # Reset the signal trap to the default behavior to clean up resources
            trap - SIGINT
        fi
    }

    # Set the trap for cleanup on SIGINT
    trap cleanup SIGINT

    llm -s "$system_prompt" "$1" | tee >(cat >"$temp_file")

    # Ensure cleanup is performed if not already done by trap
    cleanup
}

# -----------------------------------------------------------------------------
# AI-powered Git Commit Function
# Copy paste this gist into your ~/.bashrc or ~/.zshrc to gain the `gcm` command. It:
# 1) gets the current staged changed diff
# 2) sends them to an LLM to write the git commit message
# 3) allows you to easily accept, edit, regenerate, cancel
# But - just read and edit the code however you like
# the `llm` CLI util is awesome, can get it here: https://llm.datasette.io/en/stable/
# https://gist.github.com/karpathy/1dd0294ef9567971c1e4348a90d69285

lgcm() {
	# Function to generate commit message
	generate_commit_message() {
		git diff --cached | llm "
		Below is a diff of all staged changes, coming from the command:
		\`\`\`
		git diff --cached
		\`\`\`
		Please generate a concise, one-line commit message for these changes."
	}

    # Function to read user input compatibly with both Bash and Zsh
    read_input() {
	    if [ -n "$ZSH_VERSION" ]; then
		    echo -n "$1"
		    read -r REPLY
	    else
		    read -p "$1" -r REPLY
	    fi
    }

    # Main script
    echo "Generating commit message..."
    commit_message=$(generate_commit_message)

    while true; do
	    echo -e "\nProposed commit message:"
	    echo "$commit_message"

	    read_input "Do you want to (a)ccept, (e)dit, (r)egenerate, or (c)ancel? "
	    choice=$REPLY

	    case "$choice" in
		    a|A )
			    if git commit -m "$commit_message"; then
				    echo "Changes committed successfully!"
				    return 0
			    else
				    echo "Commit failed. Please check your changes and try again."
				    return 1
			    fi
			    ;;
		    e|E )
			    read_input "Enter your commit message: "
			    commit_message=$REPLY
			    if [ -n "$commit_message" ] && git commit -m "$commit_message"; then
				    echo "Changes committed successfully with your message!"
				    return 0
			    else
				    echo "Commit failed. Please check your message and try again."
				    return 1
			    fi
			    ;;
		    r|R )
			    echo "Regenerating commit message..."
			    commit_message=$(generate_commit_message)
			    ;;
		    c|C )
			    echo "Commit cancelled."
			    return 1
			    ;;
		    * )
			    echo "Invalid choice. Please try again."
			    ;;
	    esac
    done
}

if [[ -n $CURSOR_TRACE_ID ]]; then
  PROMPT_EOL_MARK=""
  test -e "./.iterm2_shell_integration.zsh" && source "$./.iterm2_shell_integration.zsh"
  precmd() { print -Pn "\e]133;D;%?\a" }
  preexec() { print -Pn "\e]133;C;\a" }
fi

# Setup tmux if not already configured
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  if [ -f "$HOME/setup_tmux.sh" ]; then
    source "$HOME/setup_tmux.sh"
  fi
fi

export PATH=/workspace/kitf/.npm-global/bin:$PATH

export HF_HUB_ENABLE_HF_TRANSFER=1
source ~/.local/bin
