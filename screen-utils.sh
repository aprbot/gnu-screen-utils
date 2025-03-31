#!/bin/bash
#
# different screen utils
#

set -a

function err-echo {
    echo "$@" > /dev/stderr
}

function get-child-pids {
    local cpid
    for cpid in $(pgrep -P $1 | xargs);
    do
        echo "$cpid"
        get-child-pids $cpid
    done
}

function get-pids-of {
    if [ -z "$1" ]
    then
        err-echo "no pid specified"
        return 1
    fi    

    echo "$1"
    get-child-pids $1
}

function htop-proc-tree {
    if [ -z "$1" ]
    then
        err-echo "no pids specified"
        return 1
    fi   
    htop --tree --pid="$(echo "$1" | xargs | tr ' ' ',')"
}

function htop-of {
    if [ -z "$1" ]
    then
        err-echo "no pid specified"
        return 1
    fi    
    htop-proc-tree "$(get-pids-of "$1")"
}

function export-proc-env {
    if [ -z "$1" ]
    then
        echo "exports process environ in format that bash can import"
        echo "usage: export-proc-env <pid> <file=stdout>"
        return 0
    fi

    local file="$2"
    if [ -z "$2" ]
    then
        file=/dev/stdout
    else
        mkdir -p "$(dirname $2)"
    fi

    #
    #   - functions definitions changes
    #   - add quotes to x=some;other --> x='some;other'
    #
    cat /proc/$1/environ | \
        tr '\0' '\n' | \
        sed -E 's@BASH_FUNC_(.*)%%=\(\)@\1()@g' | \
        sed -E "s@^(\S+)=(((.*[^'](;|\s)).+)+)@\1='\2'@g" \
            > "$file"
}

function get-proc-args {
    ps -p $1 --no-headers -o args
}

function get-screen-cmd {
    if [ -z "$1" ]
    then
        echo "returns screen cmdline with optional screen name change"
        echo "usage: get-screen-cmd <screen pid or path to cmd file> <new name> <outfile=not set> <exec=0>"
        echo -e '-twhere new name is the suffix for the current name in case it starts with _'
        echo "Notes:"
        echo "- performs only 1 action in next priority order: 1) save cmd to file; 2) exec cmd; 3) echo cmd"
        return 0
    fi

    local arg args=() n="$2" nstatus=0 name lines outfile="$3" exc="${4:-0}"
    if [ -d "/proc/$1" ]  # PID case
    then
        lines="$(
            cat /proc/$1/cmdline | tr '\0' '\n' | \
                sed -e 's|SCREEN|screen|g' -e 's|/usr/bin/screen|screen|g'
        )"

        if [ -n "$outfile" ]
        then
            mkdir -p "$(dirname "$outfile")"
        else
            lines="$(
                echo "$lines" | sed -E 's@^(.*(\s|;).*)$@"\1"@g'
            )"
        fi
    else
        lines="$(cat "$1")"
    fi

    local IFS=$'\n'

    for arg in $lines
    do
        if [ -n "$n" ]  # whether to replace name
        then
            if [ $nstatus -eq 0 ]  # if name arg not found already
            then
                if [[ "$arg" =~ -.*S ]]
                then
                    nstatus=1
                fi
            elif [ $nstatus -eq 1 ]  # if current arg is name
            then
                name="$arg"
                if [[ $n =~ _.* ]]
                then
                    name="$name$n"
                else
                    name="$n"
                fi
                arg="$name"

                nstatus=2
            fi
        fi

        args+=("$arg")
    done
    
    if [ -n "$outfile" ]
    then
        rm -rf "$outfile"
        for arg in "${args[@]}"
        do
            echo "$arg" >> "$outfile"
        done
    else
        if [ "$exc" == "1" ]
        then
            "${args[@]}"
        else
            echo "${args[@]}"
        fi
    fi
}

function _get_screens {
    /usr/bin/screen -ls | grep -P '^\s+\d+' | grep -v 'Dead ' | awk '{ print $1 }'
}

function _sort_screens_rev {
    sort -k1 -n -t'.' -r < /dev/stdin
}

function get-screen-count {
    _get_screens | wc -l
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
        local pid=${ident%.*}

        echo "$ident =>"
        echo -e "\t$(get-screen-cmd $pid)"
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
    # # screen-save wrapper with case that `screen` may be bash function here
    # (
    #     unset -f screen
    #     screen-save $@
    # )

    local pid="${1%.*}" dir="$2"
    if [ -z "$dir" ]
    then
        echo "no dir specified"
        return 1
    fi

    mkdir -p "$dir"

    export-proc-env $pid "$dir/env"
    get-screen-cmd $pid '' "$dir/cmd"
    readlink /proc/$pid/cwd > "$dir/cwd"
}

function _screen_save_clear {
    rm -rf "$1"
}

function _get_screen_temp_dir {
    if [ -z "$1" ]
    then
        err-echo "screen name is not specified!"
        return 1
    fi

    local dir="${HOME}/.screen-utils"
    mkdir -p "$dir"
    echo "$(mktemp -p "$dir" -d "$1-$(date +"%Y-%m-%d-%H-%M-%S")-XXX")"
}

function get_screen_temp_dir {
    if [ -z "$1" ]
    then
        err-echo "screen name is not specified!"
        return 1
    fi
    _get_screen_temp_dir "$(_get_screen "$1")"
}

function screen-dump {
    if [ -z "$1" ] || [ $# -gt 2 ]
    then 
        echo "dumps (saves) screen state to file"
        echo "usage: screen-dump <screen ID/NAME/ID.NAME> <dir to dump, random by default>"
        return 0
    fi

    if screen-exists "$1"
    then
        local file="$2"
        local name=''
        if [ -z "$file" ]
        then
            name="$(_get_screen "$1")"
            file="$(_get_screen_temp_dir "$name")"
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
            echo "this path is set to SU_LAST_DUMP environment variable"
        fi
    else
        echo "No such unique screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function _screen_load {
    local ct="$(get-screen-count)" ctt n
    # local envfile="$1.env"
    # (   
    #     if [ -f "$envfile" ]
    #     then
    #         set -o allexport
    #         source "$envfile"
    #         set +o allexport
    #     fi
    #     /usr/bin/screen -dmS "${2:-_loaded}" -c "$1"
    # )

    for n in cwd cmd env
    do
        if [ ! -f "$1/$n" ]
        then
            echo "$1 does not contain $1/$n, format error"
            return 1
        fi
    done

    local cwd="$(cat "$1/cwd")" envfile="$1/env"
    (
        cd "$cwd"
        set -o allexport
        source $envfile
        set +o allexport
        get-screen-cmd "$1/cmd" "$2" '' 1
    )

    #
    # wait until the screen will be really created
    #
    while :
    do
        sleep 0.01
        ctt="$(get-screen-count)"
        if (( ctt > ct ))
        then
            break
        fi
    done
}

function screen-load {
    if [ -z "$1" ] || [ $# -gt 2 ]
    then 
        echo "loads a screen from file"
        echo "usage: screen-load <path> <new screen name/_suffix>"
        return 0
    fi

    if [ ! -s "$1" ]
    then
        err-echo "file $1 not found or empty"
        return 1
    fi
    
    _screen_load "$1" "$2"
}

function screen-kill-old {
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

function _screen_kill {
    /usr/bin/screen -X -S "$1" quit
}

function screen-kill {
    _screen_select_cmd=screen-kill
    _screen_select_title="kills screens (with all child processes)"
    _screen_select_action=kill
    local out ident
    out="$(screen-select $@)"
    local rc=$?
    unset _screen_select_cmd _screen_select_title _screen_select_action
    
    if [ $rc -ne 0 ] || (echo "$out" | grep 'usage:' &> /dev/null)
    then 
        echo "$out"
        return $rc
    fi

    rc=0
    for ident in $(echo "$out" | _sort_screens_rev | xargs)
    do
        if [ "${_screen_kill_verbose:-1}" == "1" ]
        then
            echo "killing $ident ..."
        fi
        if ! _screen_kill "$ident"
        then
            echo "errors on killing $ident"
            rc=1
        fi
    done

    return $rc
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
        local file="$(_get_screen_temp_dir "$1")"
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

    # for ident in $(echo "$out" | xargs)
    # do
    #     echo "restarting $ident ..."
    #     local file="$(_get_screen_temp_file "$ident")"
    #     local name="$(_get_screen_name "$ident")"
    #     if screen-stop "$ident" "$file"
    #     then
    #         screen-load "$file" "$name"
    #         rm "$file"
    #     else
    #         err-echo "failed to restart a screen"
    #         return 1
    #     fi
    # done

    #
    # stop screens and collect result info
    #
    rc=0
    local files=() names=() index=0
    for ident in $(echo "$out" | _sort_screens_rev | xargs)
    do
        echo "stopping $ident ..."
        local file="$(_get_screen_temp_dir "$ident")"
        local name="$(_get_screen_name "$ident")"
        _screen_kill_verbose=0
        if screen-stop "$ident" "$file"
        then
            files[$index]="$file"
            names[$index]="$name"
            (( index += 1))
        else
            err-echo "failed to stop a screen $ident"
            rc=1
            break
        fi
        unset _screen_kill_verbose
    done

    #
    # up screens from info in reverse order
    #
    for index in $(seq $(( index - 1 )) -1 0)
    do
        local file="${files[$index]}"
        local name="${names[$index]}"
        echo "starting $name ..."
        screen-load "$file" "$name"
        _screen_save_clear "$file"
    done

    return $rc
}

function screen-copy {
    if [ -z "$1" ]
    then 
        echo "starts the same screen"
        echo "usage: screen-copy <screen ID/NAME/ID.NAME> <new screen name/_suffix>"
        return 0
    fi

    if screen-exists "$1"
    then
        local file="$(_get_screen_temp_dir "$1")"
        if screen-dump "$1" "$file"
        then
            screen-load "$file" "$2"
            _screen_save_clear "$file"
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
