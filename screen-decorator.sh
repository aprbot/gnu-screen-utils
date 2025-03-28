#
# provides an alias to GNU Screen command
#   which transforms some environment variables exclusively for each screen
#       depending on screen name
#
# set SDLOG=1 to enable logging
#

set -a

function screen-log {
    if [ -z "$1" ]
    then
        echo "saves message to screen log file"
        echo "usage: screen-log <screen name> <message> <type=out>"
        return 0
    fi

    if [ $# -lt 2 ]
    then
        echo "requires at least 2 args!" &>/dev/stderr
        screen-log
        return 1
    fi

    local name="$1" message="$2" kind="${3:-out}" day="$(date +"%Y-%m-%d")" time="$(date +"%T.%2N")"
    local file="${SCREEN_LOG_DIR:-/tmp/screen-log}/${day}_screen.$name.$kind.log"
    mkdir -p "$(dirname $file)"
    echo "$day $time [$BASHPID]: $message" >> "$file"
}

function _fix_env {
    #
    # removes $1 string from env variables
    #   and changes current environment
    #

    local name="$1" prefix="$(echo $1 | tr '-' '_')" msg

    [ -n "$name" ] || return 0

    msg="fixing env for screen $name ($prefix)" 
    [ -n "SDLOG" ] && echo "$msg"
    screen-log "$name" "$msg"

    for record in $(env | grep -E "^[^=]*$prefix.*=")
    do
        local n="${record%%=*}"
        local v="${record#*=}"

        local s="${n/$prefix}"

        msg="rename to $s : $n=$v"
        [ -n "SDLOG" ] && echo "$msg"
        screen-log "$name" "$msg"

        unset $n
        export $s=$v
    done 
}


function _screen_env_fixer {
    #
    # searches for screen name in input screen args
    # and translates environment for found name
    #

    local found name msg

    for arg in $@
    do 
        if [ -n "$found" ]
        then
            name="$arg"
            msg="...on starting screen $name"
            [ -n "SDLOG" ] && echo "$msg"
            screen-log "$name" "$msg"
            break
        fi

        if echo "$arg" | grep -E "\-.*S" &> /dev/null
        then
            found=1
        fi
    done

    if [ -n "$name" ]
    then
        _fix_env "$name"
    fi

}

function _screen_decorator {
    # subshell is required to not impact actual environment 
    (
        _screen_env_fixer "$@"
        /usr/bin/screen "$@"        
    )
}

if [ -e /usr/bin/screen ] 
then
    function screen {
        _screen_decorator "$@"
    }
    # alias screen=_screen_decorator
fi

set +a

