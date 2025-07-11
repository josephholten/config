# setting appropriate paths
GOPATH=$HOME/.gopath
export PATH="/home/joseph/bin/:/usr/local/texlive/2021/bin/x86_64-linux:/home/joseph/bin:/home/joseph/.config/emacs/bin:/home/joseph/.local/bin:/usr/lib/emscripten:$GOPATH:$GOPATH/bin:/opt/Citrix/ICAClient:/home/joseph/programming/gcc-cross-compiler/opt/cross/bin:/opt/adaptivecpp/bin:$PATH"
export MANPATH="/usr/local/texlive/2021/texmf-dist/doc/man:$MANPATH"
export INFOPATH="/usr/local/texlive/2021/texmf-dist/doc/info:$INFOPATH"

# CMake default variables
export CMAKE_EXPORT_COMPILE_COMMANDS=ON
export CMAKE_GENERATOR=Ninja

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
