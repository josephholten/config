#
# ~/.bashrc
#

[[ $- != *i* ]] && return

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# ----- COLOR TERMINAL ----------------

use_color=true

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
	&& type -P dircolors >/dev/null \
	&& match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

if ${use_color} ; then
	# Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
	if type -P dircolors >/dev/null ; then
		if [[ -f ~/.dir_colors ]] ; then
			eval $(dircolors -b ~/.dir_colors)
		elif [[ -f /etc/DIR_COLORS ]] ; then
			eval $(dircolors -b /etc/DIR_COLORS)
		fi
	fi

	#alias ls='ls --color=auto'
	alias ls='exa'
	alias grep='grep --colour=auto'
	alias egrep='egrep --colour=auto'
	alias fgrep='fgrep --colour=auto'
fi

unset use_color safe_term match_lhs sh

# --------------- BASH OPTIONS ------------------

xhost +local:root > /dev/null 2>&1
complete -cf sudo
# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize
shopt -s expand_aliases
# Enable history appending instead of overwriting.  #139609
shopt -s histappend
set -o vi


PROMPT_COMMAND=__prompt_command

__prompt_command() {
    local EXIT="$?"

    PS1=""

    local reset='\[\e[0m\]' # Reset colors

    local red='\[\e[1;31m\]'
    local purple='\[\e[0;35m\]'

    if [ $EUID == 0 ]; then
        local prompt_symbol="#"
        local prompt_color="${red}"
    else
        local prompt_symbol="$"
        local prompt_color="${purple}"
    fi

    PS1="${conda_env}${prompt_color}j-laptop \W ${prompt_symbol} ${reset}"
 
    if [ $EXIT != 0 ]; then
        PS1+="${red}[${EXIT}]${reset} "
    fi
}

# ---------------- PATHS & VARIABLES -----------------------------

# setting appropriate paths
export PATH="/home/joseph/bin/:/usr/local/texlive/2021/bin/x86_64-linux:/home/joseph/bin:/home/joseph/.emacs.d/bin:/home/joseph/.local/bin:$PATH"
export MANPATH="/usr/local/texlive/2021/texmf-dist/doc/man:$MANPATH"
export INFOPATH="/usr/local/texlive/2021/texmf-dist/doc/info:$INFOPATH"

# setting path s.t. python finds .pythonrc
export PYTHONSTARTUP=~/.pyhthonrc

export FZF_DEFAULT_COMMAND="fd --hidden"

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

. "$HOME/.cargo/env"



#  -------------- FUNCTIONS & ALIAS' -------------------

alias cp="cp -i"                          # confirm before overwriting something
alias df='df -h'                          # human-readable sizes
alias free='free -m'                      # show sizes in MB
alias more=less
# alias tlmgr='/usr/share/texmf-dist/scripts/texlive/tlmgr.pl --usermode' # this was needed with texlive from pacman
alias rg='ranger'
#alias lock-session="loginctl lock-session"

alias gs='git status'
alias gap='git add . -p'
alias bm='bashmount'
alias of='open $(fzf)'
alias vf='vim -c :Files!'

dc() {
    sudo docker-compose $@
}

colors() {
	local fgc bgc vals seq0

	printf "Color escapes are %s\n" '\e[${value};...;${value}m'
	printf "Values 30..37 are \e[33mforeground colors\e[m\n"
	printf "Values 40..47 are \e[43mbackground colors\e[m\n"
	printf "Value  1 gives a  \e[1mbold-faced look\e[m\n\n"

	# foreground colors
	for fgc in {30..37}; do
		# background colors
		for bgc in {40..47}; do
			fgc=${fgc#37} # white
			bgc=${bgc#40} # black

			vals="${fgc:+$fgc;}${bgc}"
			vals=${vals%%;}

			seq0="${vals:+\e[${vals}m}"
			printf "  %-9s" "${seq0:-(default)}"
			printf " ${seq0}TEXT\e[m"
			printf " \e[${vals:+${vals+$vals;}}1mBOLD\e[m"
		done
		echo; echo
	done
}

# open jupyter notebooks as background process
function jupyterd () {
    if ! $(type -t jupyter); then
        conda activate node
    fi
    jupyter notebook $@ & disown
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

cds() {
        local dir="$1"
        local dir="${dir:=$HOME}"
        if [[ -d "$dir" ]]; then
                cd "$dir" >/dev/null; ls --color=auto
        else
                echo "bash: cdls: $dir: Directory not found"
        fi
}

# ex - archive extractor
# usage: ex <file>
ex ()
{
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1     ;;
      *.gz)        gunzip $1    ;;
      *.tar)       tar xf $1    ;;
      *.tbz2)      tar xjf $1   ;;
      *.tgz)       tar xzf $1   ;;
      *.zip)       unzip $1     ;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1      ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}


function fs_drucken() {
    # if path is file
    if [ -f "$1" ]; then
        ssh mathphys lp -d sw-duplex < "$1"
    else
        echo "Error: path $1 is not a file!"
    fi
}
