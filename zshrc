# Matthew Wang's Zsh Profile for general Linux/Unix with a little Y! flavor
#

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

# Load oh-my-zsh and plugins if avilable, clone from my fork to initialize:
#
#   git clone https://github.com/ymattw/oh-my-zsh.git ~/.oh-my-zsh
#
ZSH=~/.oh-my-zsh
if [[ -f $ZSH/oh-my-zsh.sh ]]; then
    source $ZSH/oh-my-zsh.sh
    DISABLE_AUTO_UPDATE="true"
    DISABLE_CORRECTION="true"
    plugins=(git ssh)
fi

setopt prompt_subst
unsetopt nomatch

_LR='%{%B%F{red}%}'     # light red
_LG='%{%B%F{green}%}'   # light green
_LY='%{%B%F{yellow}%}'  # light yellow
_LB='%{%B%F{blue}%}'    # light blue
_LM='%{%B%F{magenta}%}' # light magenta
_LC='%{%B%F{cyan}%}'    # light cyan
_RV='%{%S%}'            # reverse
_NC='%{%b%s%F{gray}%}'  # reset color

# Functions to customize my own git promote.  FIXME: $_LR and $_LG won't get
# expanded here
#
function __git_active_branch() {
    if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]]; then
        local branch info age track
        branch=$(git symbolic-ref HEAD 2>/dev/null)
        branch=${branch##refs/heads/}
        info=$(git status -s)
        age=$(git log --pretty=format:'%cr' -1 $branch)
        track=$(git status -s -b | head -1 | sed -n 's/.*\[\(.*\)\].*/, \1/p')

        if [[ -n $info ]]; then
            print -nP "%{%b%F{red}%} ($branch) %{%b%F{cyan}%}[${age}${track}]"
        else
            print -nP "%{%b%F{green}%} ($branch) %{%b%F{cyan}%}[${age}${track}]"
        fi
    fi
}

# Fancy PROMPT, prompt exit status of last command, currenet time, hostname,
# yroot, time, cwd, git status and branch, also prompt the '%' in reverse color
# when we have background jobs.
#
PROMPT="\$([[ \$? == 0 ]] && echo '${_LG}✔' || echo '${_LR}✘') %* "

# Tip: start a global ssh-agent for yourself, for example, add this in
# /etc/rc.d/rc.local (RHEL):
#   U=ymattw
#   rm -f /home/$U/.ssh-agent.sock
#   /bin/su -m $U -c "/usr/bin/ssh-agent -s -a /home/$U/.ssh-agent.sock \
#      | sed '/^echo/d' > /home/$U/.ssh-agent.rc"
# You will need to ssh-add your identity manually once
#
if [[ -f ~/.ssh-agent.rc ]]; then
    # I am on my own machine, try load ssh-agent related environments
    PROMPT+="${_LB}"                                # blue hostname
    source ~/.ssh-agent.rc
    if ps -p ${SSH_AGENT_PID:-0} >& /dev/null; then
        if ! ssh-add -L | grep -q ^ssh-; then
            print -P "${_LR}Warning: No key is being held by ssh-agent," \
                     "try 'ssh-add <your-ssh-private-key>'${_NC}" >&2
        fi
    else
        print -P "${_LR}Warning: No global ssh-agent process alive${_NC}" >&2
    fi
else
    # Otherwise assume I am on other's box, highlight hostname in magenta
    PROMPT+="${_LM}"                                # magenta hostname
fi

PROMPT+="$(_H=$(hostname); echo ${_H%.yahoo.*})"
PROMPT+="${_LG}"                                    # then green {yroot}
PROMPT+=${YROOT_NAME+"{$YROOT_NAME}"}
PROMPT+=" ${_LY}%~${_NC}"                           # yellow cwd
PROMPT+='$(__git_active_branch)'                    # colorful git branch name
PROMPT+=" ${_LC}"$'⤾\n'                             # cyan wrap char, newline
PROMPT+="\$([[ -z \$(jobs) ]] || echo '${_RV}')"    # reverse bg job indicator
PROMPT+="%#${_NC} "                                 # % or #
unset _LR _LG _LY _LB _LM _LC _RV _NC

export EDITOR=vim
export GREP_OPTIONS="--color=auto"
export LESS="-XFR"

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