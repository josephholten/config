# setting appropriate paths
GOPATH=$HOME/.gopath
export PATH="/home/joseph/bin/:/usr/local/texlive/2021/bin/x86_64-linux:/home/joseph/bin:/home/joseph/.config/emacs/bin:/home/joseph/.local/bin:/usr/lib/emscripten:$GOPATH:$GOPATH/bin:/opt/Citrix/ICAClient:/home/joseph/programming/gcc-cross-compiler/opt/cross/bin:/opt/adaptivecpp/bin:$PATH"
export PATH=/home/joseph/.julia/bin:$PATH
export PATH="$HOME/src/spack/bin:$HOME/spack/bin:$PATH"
export MANPATH="/usr/local/texlive/2021/texmf-dist/doc/man:$MANPATH"
export INFOPATH="/usr/local/texlive/2021/texmf-dist/doc/info:$INFOPATH"

# CMake default variables
export CMAKE_EXPORT_COMPILE_COMMANDS=ON
export CMAKE_GENERATOR=Ninja

#  -------------- FUNCTIONS & ALIAS' -------------------

alias ls="ls -F --group-directories-first"
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
  fd --type f . "${1:-.}" | fzf --print0 | xargs -0 -I {} bash -c 'xdg-open "{}" & disown'
}

vf() {
  fd --type f . "${1:-.}" | fzf --print0 | xargs -0 -o vim
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

# interactive timezone picker: fuzzy-search a big city list (or just zones) and
# apply it. Uses a cached GeoNames cities db under XDG_DATA_HOME; if it's missing
# and we're online it grabs the large one (~200k cities, the tz is column 18);
# offline with no cache it falls back to the plain `timedatectl` zone list.
# rm the db file to force a refresh.
settz () {
  local datadir="${XDG_DATA_HOME:-$HOME/.local/share}"
  local datafile="$datadir/geonames-cities500.txt"
  local url="https://download.geonames.org/export/dump/cities500.zip"
  local list sel tz tmp

  if [[ ! -s "$datafile" ]]; then
    mkdir -p "$datadir"
    tmp=$(mktemp)
    if curl -fsSL --connect-timeout 5 -o "$tmp" "$url" 2>/dev/null \
       && bsdtar -xOf "$tmp" cities500.txt > "$datafile" 2>/dev/null; then
      echo "settz: cached city database at $datafile" >&2
    else
      rm -f "$datafile"   # no half-written/empty db
    fi
    rm -f "$tmp"
  fi

  if [[ -s "$datafile" ]]; then
    # GeoNames cities (col 2=name 9=country 15=pop 18=tz), pop-sorted, plus the
    # raw IANA zones; each line is "<display>\t<tz>", deduped on the whole line.
    list=$(
      { awk -F'\t' '$18 != "" {
            printf "%s\t%s, %s  \xE2\x86\x92  %s\t%s\n", $15, $2, $9, $18, $18 }' "$datafile" \
          | sort -t$'\t' -k1,1nr | cut -f2- ;
        timedatectl list-timezones | awk '{ print $1 "\t" $1 }' ;
      } | awk -F'\t' '!seen[$0]++'
    )
  else
    list=$(timedatectl list-timezones | awk '{ print $1 "\t" $1 }')
  fi

  sel=$(fzf --delimiter='\t' --with-nth=1 --prompt='timezone> ' <<< "$list") || return
  tz=$(cut -f2 <<< "$sel")
  [[ -n "$tz" ]] && sudo timedatectl set-timezone "$tz"
}


timer() {
  msg=$1; shift
  echo "DISPLAY=:0 ~/bin/fullscreen_warning -m '$msg' -b blue" | at $@ 2> /dev/null
}

ssh-persist() {
  if ssh -O check "$@" 2>/dev/null; then
    echo "master already running — 'ssh -O exit <host>' first"
    return 1
  fi
  ssh -MNf -o ControlPersist="${SSH_PERSIST:-48h}" "$@"
}
