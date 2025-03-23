#!/bin/bash
#
# different screen utils
#

set -a

function _get_screens {
    /usr/bin/screen -ls | grep -P '^\s+\d+' | grep -v 'Dead ' | awk '{ print $1 }'
}

function _get_screen {
    if [ -z "$1" ]
    then
        echo "screen ident is not specified!"
        return 1
    fi
    _get_screens | grep "$1"
}

function _get_screen_name {

    local ident
    ident="$(_get_screen "$1")"
    if [ $? -ne 0 ]
    then
        echo "$ident"
        return 1
    fi
    echo "${ident#*.}"
}

function dump_screen_output {
    local name=$1
    if [ -z "$name" ]
    then 
        echo "dumps screen output to file"
        echo "usage: dump_screen_output <screen ID/NAME/ID.NAME> <file>"
        return 0
    fi
    local file=${2:-/tmp/screen_output}

    mkdir -p "$(dirname "$file")"
    if /usr/bin/screen -X -S "$name" hardcopy -h $file
    then
        echo "screen $name log is dumped to $file"
    else
        echo -e "ERROR: bad screen name $name\n\nexisting screens:"
        /usr/bin/screen -ls
    fi
}

function dump_screens_output {
    if [ $# -eq 1 ] && [ -z "$1" ]
    then 
        echo "dumps ALL running screens output to directory"
        echo "usage: dump_screens_output <output folder>"
        return 0
    fi

    local folder=${1:-/tmp/screen_output.d}
    local ident
    for ident in $(_get_screens)
    do 
        local number=${ident%.*}
        local name=${ident#*.}

        dump_screen_output $ident "$folder/$name.$number.txt"
    done
}

function screen-ls {
    if [ $# -ne 0 ]
    then
        echo "shows running screens"
        echo "usage: screen-ls"
        return 0
    fi

    for ident in $(_get_screens)
    do 
        local number=${ident%.*}

        echo "$ident =>"
        echo -e "\t$(ps -p $number -o args | tail -1)"
        echo
    done
}

function screen-counts {
    if [ $# -ne 0 ]
    then
        echo "shows running screens counts (grouped by name)"
        echo "usage: screen-counts"
        return 0
    fi

    declare -A n2pids
    declare -A n2count
    for ident in $(_get_screens)
    do 
        local number=${ident%.*}
        local name=${ident#*.}
        
        local count="${n2count["$name"]}"
        if [ -z "$count" ]
        then
            n2count["$name"]=1
            n2pids["$name"]="$number"
        else
            n2count["$name"]=$((count + 1))
            n2pids["$name"]="${n2pids["$name"]} $number"
        fi
    done

    for name in ${!n2count[@]}
    do
        echo -e "\t$name=${n2count["$name"]}, ${n2pids["$name"]}"
    done

}

function screen-exists {
    if [ -z "$1" ]
    then 
        echo "usage: screen-exists <screen ID/NAME/ID.NAME>"
        return 0
    fi
    /usr/bin/screen -S "$1" -Q select . &> /dev/null
}

function _screen_save {
    # screen-save wrapper with case that `screen` may be bash function here
    (
        unset -f screen
        screen-save $@
    )
}

function _get_screen_temp_file {
    if [ -z "$1" ]
    then
        echo "screen name is not specified!"
        return 1
    fi

    local dir="${HOME}/.screen-utils"
    mkdir -p "$dir"
    local name="$(_get_screen "$1")"
    echo "$(mktemp -p "$dir" "$name-$(date +"%Y-%m-%d-%H-%M-%S")-XXX")"
}

function screen-dump {
    if [ -z "$1" ] || [ $# -gt 2 ]
    then 
        echo "dumps (saves) screen state to file"
        echo "usage: screen-dump <screen ID/NAME/ID.NAME> <file to dump, random by default>"
        return 0
    fi

    if screen-exists "$1"
    then
        local file="$2"
        local name=''
        if [ -z "$file" ]
        then
            name="$(_get_screen "$1")"
            file="$(_get_screen_temp_file "$1")"
        fi
        _screen_save "$1" "$file"
        if [ ! -s "$file" ]
        then
            echo "something went wrong, screen file is not created"
            return 1
        fi
        export SU_LAST_DUMP="$file"
        if [ -n "$name" ]
        then
            echo "screen $name is dumped to $file"
            echo "this file path is set to SU_LAST_DUMP environment variable"
        fi
    else
        echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-load {
    if [ -z "$1" ] || [ $# -gt 2 ]
    then 
        echo "loads a screen from file"
        echo "usage: screen-load <path> <new screen name>"
        return 0
    fi

    if [ ! -s "$1" ]
    then
        echo "file $1 not found or empty"
        return 1
    fi

    /usr/bin/screen -dmS "${2:-_loaded}" -c "$1" 

}

function screen-kill {
    if [ -z "$1" ]
    then 
        echo "kills a screen"
        echo "usage: screen-kill <screen ID/NAME/ID.NAME>"
        return 0
    fi

    if screen-exists "$1"
    then
        /usr/bin/screen -X -S "$1" quit
    else
        echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-stop {
    if [ -z "$1" ] || [ $# -gt 2 ]
    then 
        echo "stops (kills) a screen with saving its state to allow recreation"
        echo "usage: screen-stop <screen ID/NAME/ID.NAME> <file to save state, random by default>"
        return 0
    fi

    if screen-exists "$1"
    then
        if screen-dump "$1" "$2"
        then
            screen-kill "$1"
        else 
            echo "cancelling screen killing"
            return 1
        fi
    else
        echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-restart {
    if [ -z "$1" ]
    then 
        echo "restarts a screen"
        echo "usage: screen-restart <screen ID/NAME/ID.NAME>"
        return 0
    fi

    if screen-exists "$1"
    then
        local file="$(_get_screen_temp_file "$1")"
        local name="$(_get_screen_name "$1")"
        if screen-stop "$1" "$file"
        then
            screen-load "$file" "$name"
            rm "$file"
        else
            echo "failed to restart a screen"
            return 1
        fi
    else
        echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-copy {
    if [ -z "$1" ]
    then 
        echo "starts the same screen"
        echo "usage: screen-copy <screen ID/NAME/ID.NAME>"
        return 0
    fi

    if screen-exists "$1"
    then
        local file="$(_get_screen_temp_file "$1")"
        if screen-dump "$1" "$file"
        then
            screen-load "$file" "$(_get_screen_name "$1")"
            rm "$file"
        else
            echo "failed to copy a screen"
            return 1
        fi
    else
        echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}


function screen-utils-help {
    for ff in "dump_screen_output" "dump_screens_output" "screen-ls" "screen-counts" "screen-dump" "screen-load" "screen-kill" "screen-stop" "screen-restart" "screen-copy"
    do
        echo "==== $ff ===="
        $ff ''
        echo
    done

    echo "==== screen-utils-help ===="
    echo -e "\tshow this message"
    echo
}


set +a

# show help in interactive mode
if [[ $- == *i* ]] || [ "${RUN_INTERACTIVE_PARTS}" == '1' ]
then
    screen-utils-help
fi
