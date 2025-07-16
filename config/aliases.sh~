# -------------------------------------------------------------------
# o
# personal
# -------------------------------------------------------------------

alias cdg="cd ~/git"
alias zrc="cd $DOT_DIR/zsh"
alias dot="cd $DOT_DIR"
alias jp="jupyter lab"
alias hn="hostname"

# -------------------------------------------------------------------
# general
# -------------------------------------------------------------------

alias cl="clear"

# file and directories
alias rm='rm -i'
alias rmd='rm -rf'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# find/read files
alias h='head'
alias t='tail'
# alias rl="readlink -f"
alias fd='find . -type d -name'
alias ff='find . -type f -name'
alias which='type -a'

# storage
alias du='du -kh' # file space
alias df='df -kTh' # disk space
alias usage='du -sh * 2>/dev/null | sort -rh'
alias dus='du -sckx * | sort -nr'

# add to path
function add_to_path() {
    p=$1
    if [[ "$PATH" != *"$p"* ]]; then
      export PATH="$p:$PATH"
    fi
}

#
#-------------------------------------------------------------
# cd
#-------------------------------------------------------------

alias c='cd'
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'
alias .2='cd ../../'
alias .3='cd ../../../'
alias .4='cd ../../../../'
alias .5='cd ../../../../..'
alias /='cd /'

alias d='dirs -v'
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'


#-------------------------------------------------------------
# git
#-------------------------------------------------------------

alias g="git"
alias gcl="git clone"
alias ga="git add"
alias gaa="git add ."
alias gau="git add -u"
alias gc="git commit -m"
alias gp="git push"
alias gac="git add * && git commit -m" 
alias gpf="git push -f"
alias gpo='git push origin $(git_current_branch)'
alias gpp='git push --set-upstream origin $(git_current_branch)'

alias gg='git gui'
alias glog='git log --oneline --all --graph --decorate'

alias gf="git fetch"
alias gl="git pull"

alias grb="git rebase"
alias grbm="git rebase main"
alias grbc="git rebase --continue"
alias grbs="git rebase --skip"
alias grba="git rebase --abort"

alias gd="git diff"
alias gdt="git difftool"
alias gs="git status"

alias gco="git checkout"
alias gcb="git checkout -b"
alias gcm="git checkout main"

alias grhead="git reset HEAD^"
alias grhard="git fetch origin && git reset --hard"

alias gst="git stash"
alias gstp="git stash pop"
alias gsta="git stash apply"
alias gstd="git stash drop"
alias gstc="git stash clear"

alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias gpsup='git push --set-upstream origin $(git_current_branch)'

#-------------------------------------------------------------
# tmux
#-------------------------------------------------------------

alias ta="tmux attach"
alias taa="tmux attach -t"
alias tad="tmux attach -d -t"
alias td="tmux detach"
alias ts="tmux new-session -s"
alias tl="tmux list-sessions"
alias tkill="tmux kill-server"
alias tdel="tmux kill-session -t"

#-------------------------------------------------------------
# ls
#-------------------------------------------------------------

alias l="ls -CF --color=auto"
alias ll="ls -l --group-directories-first"
alias la='ls -Al'         # show hidden files
alias lx='ls -lXB'        # sort by extension
alias lk='ls -lSr'        # sort by size, biggest last
alias lc='ls -ltcr'       # sort by and show change time, most recent last
alias lu='ls -ltur'       # sort by and show access time, most recent last
alias lt='ls -ltr'        # sort by date, most recent last
alias lm='ls -al |more'   # pipe through 'more'
alias lr='ls -lR'         # recursive ls
alias tree='tree -Csu'    # nice alternative to 'recursive ls'

#-------------------------------------------------------------
# chmod
#-------------------------------------------------------------

chw () {
  if [ "$#" -eq 1 ]; then
    chmod a+w $1
  else
    echo "Usage: chw <dir>" >&2
  fi
}
chx () {
  if [ "$#" -eq 1 ]; then
    chmod a+x $1
  else
    echo "Usage: chx <dir>" >&2
  fi
}

#-------------------------------------------------------------
# env
#-------------------------------------------------------------
alias sv="source .venv/bin/activate"
alias de="deactivate"
alias ma="micromamba activate"
alias md="micromamba deactivate"

# -------------------------------------------------------------------
# Slurm
# -------------------------------------------------------------------
alias q='squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
alias qw='watch squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
alias qq='squeue -u $(whoami) -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
alias qtop='scontrol top'
alias qdel='scancel'
alias qnode='sinfo -Ne --Format=NodeHost,CPUsState,Gres,GresUsed'
alias qinfo='sinfo'
alias qhost='scontrol show nodes'
# Submit a quick GPU test job
alias qtest='sbatch --gres=gpu:1 --wrap="hostname; nvidia-smi"'
alias qlogin='srun --gres=gpu:1 --pty $SHELL'
# Cancel all your queued jobs
alias qclear='scancel -u $(whoami)'
# Functions to submit quick jobs with varying GPUs
# Usage: qrun 4 script.sh → submits 'script.sh' with 4 GPUs
qrun() {
  sbatch --gres=gpu:"$1" "$2"
}
alias uvinstall="uv pip install --update-requirements requirements.txt"

alias getenvs="/workspace/kitf/setup_env.sh"
alias vim="nvim"

lessrf() {
    less +F -r logs/*"$1"*
}
lessrfe() {
    less +F -r logs/*"$1"*.err
}
lessrfo() {
    less +F -r logs/*"$1"*.out
}
vimp() {
    local files=""
    for arg in "$@"; do
        files="$files logs/*$arg*"
        files="$files *$arg*"
    done
    vim -p $files
}
lessrf() {
    local files=()
    local err_files=()
    local out_files=()

    # Find and sort .err files by modification time (newest first)
    while IFS= read -r -d '' file; do
        err_files+=("$file")
    done < <(find logs -name "*$1*.err" -type f -printf '%T@\t%p\0' 2>/dev/null | sort -zrn | cut -f2-)

    # Find and sort .out files by modification time (newest first)
    while IFS= read -r -d '' file; do
        out_files+=("$file")
    done < <(find logs -name "*$1*.out" -type f -printf '%T@\t%p\0' 2>/dev/null | sort -zrn | cut -f2-)

    # Interleave err and out files
    local max_len=${#err_files[@]}
    [[ ${#out_files[@]} -gt $max_len ]] && max_len=${#out_files[@]}

    for ((i=0; i<max_len; i++)); do
        [[ $i -lt ${#err_files[@]} ]] && files+=("${err_files[$i]}")
        [[ $i -lt ${#out_files[@]} ]] && files+=("${out_files[$i]}")
    done

    # Add any other matching files (not .err or .out) sorted by time
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find logs -name "*$1*" -type f ! -name "*.err" ! -name "*.out" -printf '%T@\t%p\0' 2>/dev/null | sort -zrn | cut -f2-)

    [[ ${#files[@]} -eq 0 ]] && { echo "No matching files found"; return 1; }

    less +F -r "${files[@]}"
}

lessrfe() {
    local files=()

    # Find and sort .err files by modification time (newest first)
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find logs -name "*$1*.err" -type f -printf '%T@\t%p\0' 2>/dev/null | sort -zrn | cut -f2-)

    [[ ${#files[@]} -eq 0 ]] && { echo "No matching .err files found"; return 1; }

    less +F -r "${files[@]}"
}

lessrfo() {
    local files=()

    # Find and sort .out files by modification time (newest first)
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find logs -name "*$1*.out" -type f -printf '%T@\t%p\0' 2>/dev/null | sort -zrn | cut -f2-)

    [[ ${#files[@]} -eq 0 ]] && { echo "No matching .out files found"; return 1; }

    less +F -r "${files[@]}"
}

vimp() {
    local files=""
    for arg in "$@"; do
        files="$files logs/*$arg*"
        files="$files *$arg*"
    done
    vim -p $files
}
