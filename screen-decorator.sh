#
# provides an alias to GNU Screen command
#   which transforms some environment variables exclusively for each screen
#       depending on screen name
#
# set SDLOG=1 to enable logging
#

set -a

function _fix_env {
    #
    # removes $1 string from env variables
    #   and changes current environment
    #

    local name="$1"

    [ -n "$name" ] || return 0

    [ -n "SDLOG" ] && echo "fixing env for name: $name" 

    for record in $(env | grep -E "^[^=]*$name.*=")
    do
        local n="${record%%=*}"
        local v="${record#*=}"

        local s="${n/$name}"

        [ -n "SDLOG" ] && echo "rename to $s : $n=$v"

        unset $n
        export $s=$v
    done 
}


function _screen_env_fixer {

    local found=
    local name=

    for arg in $@
    do 
        if [ -n "$found" ]
        then
            name="$arg"
            [ -n "SDLOG" ] && echo "found screen name: $name"
            break
        fi

        if echo "$arg" | grep -E "\-.*S" &> /dev/null
        then
            found=1
        fi
    done

    if [ -n "$name" ]
    then
        _fix_env "$(echo $name | tr '-' '_')"
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

