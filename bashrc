#
# ~/.bashrc
#

[[ $- != *i* ]] && return

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

[ -r $HOME/config/bash_defs.sh ] && . $HOME/config/bash_defs.sh

#
# --------------- BASH OPTIONS ------------------

complete -cf sudo
shopt -s checkwinsize
shopt -s expand_aliases
shopt -s histappend
shopt -s extglob
shopt -s dotglob
shopt -s globstar


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

# --------------- GPG ---------------
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
gpg-connect-agent updatestartuptty /bye > /dev/null
