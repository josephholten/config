#
# ~/.bashrc
#

[[ $- != *i* ]] && return

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion
#
# --------------- BASH OPTIONS ------------------

complete -cf sudo
shopt -s checkwinsize
shopt -s expand_aliases
shopt -s histappend
shopt -s extglob
shopt -s dotglob
shopt -s globstar
set -o vi


PROMPT_COMMAND=__prompt_command

__prompt_command() {
    local EXIT="$?"

    PS1=""

    local reset='\[\e[0m\]' # Reset colors
    local red='\[\e[1;31m\]'
    local purple='\[\e[0;35m\]'
    local bold='\[\e[1m\]'

    # Check if we are connected via SSH
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
        local host_info="${bold}\h "
    else
        local host_info=""
    fi

    if [ $EUID == 0 ]; then
        local prompt_symbol="#"
        local prompt_color="${red}"
    else
        local prompt_symbol="$"
        local prompt_color="${purple}"
    fi

    PS1="${prompt_color}${host_info}\W ${prompt_symbol} ${reset}"

    if [ $EXIT != 0 ]; then
        PS1+="${red}[${EXIT}]${reset} "
    fi
}

# ---------------- PATHS & VARIABLES -----------------------------

# setting appropriate paths
GOPATH=$HOME/.gopath
export PATH="/home/joseph/bin/:/usr/local/texlive/2021/bin/x86_64-linux:/home/joseph/bin:/home/joseph/.config/emacs/bin:/home/joseph/.local/bin:/usr/lib/emscripten:$GOPATH:$GOPATH/bin:/opt/Citrix/ICAClient:/home/joseph/programming/gcc-cross-compiler/opt/cross/bin:/opt/adaptivecpp/bin:$PATH"
export MANPATH="/usr/local/texlive/2021/texmf-dist/doc/man:$MANPATH"
export INFOPATH="/usr/local/texlive/2021/texmf-dist/doc/info:$INFOPATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/joseph/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/joseph/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/joseph/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/joseph/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<



#  -------------- FUNCTIONS & ALIAS' -------------------

alias ls="ls --color --group-directories-first"
alias cp="cp -ir"                          # confirm before overwriting something
alias mv="mv -i"                           # confirm before overwriting something
alias more=less
alias rg='ranger'

alias vim='vim --servername vim'
alias gs='git status'
alias gd='git diff'
alias gap='git add . -p'
alias grp='git restore . -p'
alias wgup='sudo wg-quick up wg0'
alias wgdown='sudo wg-quick down wg0'
alias rclone='rclone --verbose --progress'
alias em="emacsclient"

of() {
    fd --hidden --type f | fzf --print0 | xargs -0 -I {} bash -c 'xdg-open "{}" & disown'
}

vf() {
    fd --hidden --type f | fzf --print0 | xargs -0 -o vim
}

dc() {
    sudo docker-compose $@
}

# open stuff in the background
function open () {
    for file in "$@"; do
        if [ -f "$file" ]; then
            xdg-open "$file" & disown
        elif [ -d "$file" ]; then
            ranger "$file"
        else
            echo "Error: Cannot open $file, is neither directory nor file."
        fi
    done
}

export KEYID=0x22C0152F739C743D

wakeserver () {
    ssh joseph-pi 'wakeonlan 7C:05:07:0D:FE:E5'
}

gpgencrypt () {
  output="${1}".$(date +%s).enc
  gpg --encrypt --armor --output ${output} \
    -r $KEYID "${1}" && echo "${1} -> ${output}"
}

gpgdecrypt () {
  output=$(echo "${1}" | rev | cut -c16- | rev)
  gpg --decrypt --output ${output} "${1}" && \
    echo "${1} -> ${output}"
}

export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye > /dev/null
