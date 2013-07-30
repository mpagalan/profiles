# Matthew Wang's Zsh Profile for general Linux/Unix with a little Y! flavor
#
# To initialize ~/.oh-my-zsh, clone from my fork:
#
#   git clone git://github.com/ymattw/oh-my-zsh.git ~/.oh-my-zsh
#
ZSH=$HOME/.oh-my-zsh

# Customized PATH
#
function path_prepend() {
    local x
    for x in "$@"; do
        [[ :$PATH: == *:$x:* ]] || PATH=$x:$PATH
    done
}
path_prepend /bin /usr/bin /sbin /usr/sbin /usr/local/bin /usr/local/sbin ~/bin
[[ ! -d /opt/local/bin ]] || path_prepend /opt/local/bin
[[ ! -d /home/y/bin64 ]] || path_prepend /home/y/bin64
[[ ! -d /home/y/bin ]] || path_prepend /home/y/bin
unset path_prepend
export PATH

# Functions to customize my own git promote
#
function __git_status_color() {
    git symbolic-ref HEAD >& /dev/null || return 0
    if [[ -n $(git status -s 2>/dev/null) ]]; then
        echo -e "\033[1;31m"        # red status
    else
        echo -e "\033[1;32m"        # green status
    fi
}

function __git_active_branch() {
    local branch=$(git symbolic-ref HEAD 2>/dev/null)
    [[ -z $branch ]] || echo " (${branch##refs/heads/})"
}

# Load oh-my-zsh and plugins
#
DISABLE_AUTO_UPDATE="true"
DISABLE_CORRECTION="true"
plugins=(git ssh)
source $ZSH/oh-my-zsh.sh
unalias g

# Tip: start a global ssh-agent for yourself, for example, add this in
# /etc/rc.d/rc.local (RHEL):
#   U=ymattw
#   rm -f /home/$U/.ssh-agent.sock
#   /bin/su -m $U -c "/usr/bin/ssh-agent -s -a /home/$U/.ssh-agent.sock \
#      | sed '/^echo/d' > /home/$U/.ssh-agent.rc"
# You will need to ssh-add your identity manually once
#

# Fancy PROMPT, prompt exit status of last command, currenet time, hostname,
# yroot, time, cwd, git status and branch, also prompt the '%' in reverse color
# when we have background jobs.
#
PROMPT="\$([[ \$? == 0 ]] && echo '\e[1;32m✔' || echo '\e[1;31m✘') %* "

if [[ -f ~/.ssh-agent.rc ]]; then
    # I am on my own machine, try load ssh-agent related environments
    PROMPT+='%{$fg[blue]%}'                         # blue hostname
    . ~/.ssh-agent.rc
    if ps -p ${SSH_AGENT_PID:-0} >& /dev/null; then
        if ! ssh-add -L | grep -q ^ssh-; then
            echo -e "\033[1;31mWarning: No key is being held by ssh-agent," \
                    "try 'ssh-add <your-ssh-private-key>'\x1b[0m" >&2
        fi
    else
        echo -e "\033[1;31mWarning: No global ssh-agent process alive" >&2
    fi
else
    # Otherwise assume I am on other's box, highlight hostname in red
    PROMPT+='%{$fg[magenta]%}'                      # magenta hostname
fi

PROMPT+="$(_H=$(hostname); echo ${_H%.yahoo.*})"
PROMPT+='%{$fg[green]%}'                            # then green {yroot}
PROMPT+="${YROOT_NAME+\{$YROOT_NAME\}}"
PROMPT+=' %{$fg[yellow]%}%~%{$reset_color%}'        # yellow cwd
PROMPT+='$(__git_status_color)'                     # git status indicator
PROMPT+='$(__git_active_branch)'                    # git branch name
PROMPT+=' %{$fg[cyan]%}⤾
'                                                   # cyan wrap char, newline
PROMPT+='$([[ -z $(jobs) ]] || echo "\e[7m")'       # reverse bg job indicator
PROMPT+='%#%{$reset_color%} '                       # % or #

export EDITOR=vim
export GREP_OPTIONS="--color=auto"
export LESS="-XFR"
unsetopt nomatch

# Locale matters for ls and sort
# www.gnu.org/software/coreutils/faq/#Sort-does-not-sort-in-normal-order_0021
export LC_COLLATE=C
export LC_CTYPE=C

# Shortcuts (Aliases, function, auto completion etc.)
#
case $(uname -s) in
    Linux)
        alias ls='/bin/ls -F --color=auto'
        alias l='/bin/ls -lF --color=auto'
        alias lsps='ps -ef f | grep -vw grep | grep -i'
        ;;
    Darwin)
        alias ls='/bin/ls -F'
        alias l='/bin/ls -lF'
        alias lsps='ps -ax -o user,pid,ppid,stime,tty,time,command | grep -vw grep | grep -i'
        ;;
    *)
        alias ls='/bin/ls -F'
        alias l='/bin/ls -lF'
        alias lsps='ps -auf | grep -vw grep | grep -i'
        ;;
esac

# Find a file which name matches given pattern (ERE, case insensitive)
function f() {
    local pat=${1?'Usage: f ERE-pattern [path...]'}
    shift
    find ${@:-.} \( -path '*/.svn' -o -path '*/.git' -o -path '*/.idea' \) \
        -prune -o -print -follow | grep -iE "$pat"
}

# Load file list generated by function f() above in vim, you can type 'gf' to
# jump to the file
#
function vif() {
    local tmpf=$(mktemp)
    f "$@" > $tmpf && vi -c "/$1" $tmpf && rm -f $tmpf
}

# Grep a ERE pattern in files that match given file glob in cwd or given path
function g() {
    local string_pat=${1:?"Usage: g ERE-pattern [file-glob] [grep opts] [path...]"}
    shift
    local file_glob grep_opts paths

    while (( $# > 0 )); do
        case "$1" in
            *\**|*\?*|*\]*) file_glob="$1"; shift;;
            -*) grep_opts="$grep_opts $1"; shift;;
            *) paths="$paths $1"; shift;;
        esac
    done
    [[ -n "$file_glob" ]] || file_glob="*"
    [[ -n "$paths" ]] || paths="."

    find $paths \( -path '*/.svn' -o -path '*/.git' -o -path '*/.idea' \) \
        -prune -o -type f -name "$file_glob" -print0 -follow \
        | xargs -0 -P128 grep -EH $grep_opts "$string_pat"
}

# vim:set et sts=4 sw=4 ft=zsh:
