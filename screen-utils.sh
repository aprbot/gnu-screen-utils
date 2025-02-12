#
# different screen utils
#

set -a

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
    if [ -z "$1" ]
    then 
        echo "dumps ALL running screens output to directory"
        echo "usage: dump_screens_output <output folder>"
        return 0
    fi

    local folder=${1:-/tmp/screen_output.d}
    local ident
    for ident in $(/usr/bin/screen -ls | grep -P '^\s+\d+' | grep -v 'Dead ' | awk '{ print $1 }')
    do 
        number=${ident%.*}
        name=${ident#*.}

        dump_screen_output $ident "$folder/$name.$number.txt"
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

function screen-stop {
    if [ -z "$1" ]
    then 
        echo "stops (kills) a screen"
        echo "usage: screen-stop <screen ID/NAME/ID.NAME>"
        return 0
    fi

    if screen-exists "$1"
    then
        /usr/bin/screen screen -X -S "$1" quit
    else
        echo "No such screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}

function screen-restart {
    if [ -z "$1" ]
    then 
        echo "restarts a screen (keeping environment)"
        echo "usage: screen-restart <screen ID/NAME/ID.NAME>"
        return 0
    fi

    if screen-exists "$1"
    then
        local file="$(mktemp)"
        screen-save "$1" "$file"
        screen-stop "$1"
        /usr/bin/screen -dmS _screen -c "$file" 
    else
        echo "No such screen: $1" 1>&2
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
        local file="$(mktemp)"
        screen-save "$1" "$file"
        /usr/bin/screen -dmS _screen -c "$file" 
    else
        echo "No such screen: $1" 1>&2
        /usr/bin/screen -ls
        return 1
    fi
}


function screen-utils-help {
    for ff in "dump_screen_output" "dump_screens_output" "screen-stop" "screen-restart" "screen-copy"
    do
        echo "==== $ff ===="
        $ff ''
        echo
    done
}


set +a

# show help in interactive mode
if [[ $- == *i* ]] || [ "${RUN_INTERACTIVE_PARTS}" -eq 1 ]
then
    screen-utils-help
fi
