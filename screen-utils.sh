#!/bin/bash
#
# different screen utils
#

set -a

function err-echo {
    echo "$@" > /dev/stderr
}

function get-child-pids() {
    local cpid
    for cpid in $(pgrep -P $1 | xargs);
    do
        echo "$cpid"
        get-child-pids $cpid
    done
}

function get-pids-of() {
    if [ -z "$1" ]
    then
        err-echo "no pid specified"
        return 1
    fi    

    echo "$1"
    get-child-pids $1
}

function htop-proc-tree() {
    if [ -z "$1" ]
    then
        err-echo "no pids specified"
        return 1
    fi   
    htop --tree --pid="$(echo "$1" | xargs | tr ' ' ',')"
}

function htop-of() {
    if [ -z "$1" ]
    then
        err-echo "no pid specified"
        return 1
    fi    
    htop-proc-tree "$(get-pids-of "$1")"
}

function _get_screens {
    /usr/bin/screen -ls | grep -P '^\s+\d+' | grep -v 'Dead ' | awk '{ print $1 }'
}

function _get_screen {
    if [ -z "$1" ]
    then
        err-echo "screen ident is not specified!"
        return 1
    fi
    _get_screens | grep -- "$1"
}

function _get_screen_name {

    local ident
    ident="$(_get_screen "$1")"
    if [ $? -ne 0 ]
    then
        err-echo "$ident"
        return 1
    fi
    echo "${ident#*.}"
}

function _screen_select_help {
    local cmd="${_screen_select_cmd}"
    local title="${_screen_select_title}"
    local action="${_screen_select_action}"
    if [ -z "$cmd" ]
    then
        cmd=screen-select
        title="shows running screens idents according to filters"
        action=select
    fi

    echo "$title"
    echo "usage:"
    echo -e "\t$cmd -a/--all (to $action all screens)"
    echo -e "\t$cmd <screen ID/NAME/ID.NAME> (to $action only 1 screen matches this ident)"
    echo -e "\t$cmd -g/--grep <pattern> (to $action all screens matches this grep pattern)"
    echo -e "\t$cmd -r/--regex <pattern> (to $action all screens matches this grep -P regex)"
}

function screen-select {
    if [ $# -eq 0 ]
    then
        _screen_select_help
        return 0
    fi

    if [ $# -gt 2 ] || ([ $# -eq 2 ] && [ -z "$2" ])
    then
        _screen_select_help
        return 1
    fi

    if [ $# -eq 1 ] 
    then
        if [ -z "$1" ]
        then
            _screen_select_help
            return 0
        fi

        if [ "$1" == "-a" ] || [ "$1" == "--all" ]
        then
            _get_screens
            return 0
        fi
        
        local idents
        idents="$(_get_screen "$1")"
        if [ $? -ne 0 ]
        then
            err-echo "no screens matching ident $1"
            _screen_select_help
            return 1
        fi

        local count="$(echo "$idents" | wc -l)"
        if [ "$count" == "1" ]
        then
            echo "$idents"
            return 0
        fi

        err-echo "there are $count screens matching ident $1"
        echo "$idents"
        return 1
    fi

    if [ "$1" == "-g" ] || [ "$1" == "--grep" ]
    then
        local idents
        idents="$(_get_screen "$2")"
        if [ $? -ne 0 ]
        then
            err-echo "no screens matching --grep $2"
            _screen_select_help
            return 1
        fi
        echo "$idents"
        return 0
    fi

    if [ "$1" == "-r" ] || [ "$1" == "--regex" ]
    then
        local idents
        idents="$(_get_screens | grep -P -- "$2")"
        if [ $? -ne 0 ]
        then
            err-echo "no screens matching --regex $2"
            _screen_select_help
            return 1
        fi
        echo "$idents"
        return 0
    fi

    _screen_select_help
    return 1
}

function get-screen-tree-pids() {
    if [ $# -ne 0 ]
    then
        echo "returns PIDs of all active screens and their child processes (recursively)"
        echo "usage: get-screen-tree-pids"
        return 0
    fi

    local pid p=""
    for pid in $(screen-select --all | cut -d'.' -f1)
    do
        p="$p $(get-pids-of $pid | xargs)"
    done
    echo "$p" | xargs
}

function screen-top() {
    if [ $# -ne 0 ]
    then
        echo "runs htop --tree for all active screens and their child processes (recursively)"
        echo "usage: screen-htop"
        return 0
    fi
    htop-proc-tree "$(get-screen-tree-pids)"
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
        err-echo -e "ERROR: bad screen name $name\n\nexisting screens:"
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
        err-echo "screen name is not specified!"
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
        err-echo "file $1 not found or empty"
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
        err-echo "No such unique screen: $1" 1>&2
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
            err-echo "cancelling screen killing"
            return 1
        fi
    else
        err-echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-restart-old {
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
            err-echo "failed to restart a screen"
            return 1
        fi
    else
        err-echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-restart {
    _screen_select_cmd=screen-restart
    _screen_select_title="restarts screens"
    _screen_select_action=restart
    local out ident
    out="$(screen-select $@)"
    local rc=$?
    unset _screen_select_cmd _screen_select_title _screen_select_action
    
    if [ $rc -ne 0 ] || (echo "$out" | grep 'usage:' &> /dev/null)
    then 
        echo "$out"
        return $rc
    fi

    for ident in $(echo "$out" | xargs)
    do
        echo "restarting $ident ..."
        local file="$(_get_screen_temp_file "$ident")"
        local name="$(_get_screen_name "$ident")"
        if screen-stop "$ident" "$file"
        then
            screen-load "$file" "$name"
            rm "$file"
        else
            err-echo "failed to restart a screen"
            return 1
        fi
    done
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
            err-echo "failed to copy a screen"
            return 1
        fi
    else
        err-echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}


function screen-utils-help {
    for ff in "screen-select" "get-screen-tree-pids" "screen-top" "dump_screen_output" "dump_screens_output" "screen-ls" "screen-counts" "screen-dump" "screen-load" "screen-kill" "screen-stop" "screen-restart" "screen-copy"
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
