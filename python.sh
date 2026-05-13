#!/bin/bash

#
# wrapper on some venv/bin/python executable which logs command start and exit
# 
# usage:
#   1) replace existing python with this script using: ./python.sh <path to venv>
#   2) specify next environment variables:
#       * PYTHON_WRAPPER_OUT_FILE: path to out file (date patterns are allowed)
#       * PYTHON_WRAPPER_ERR_FILE='': path to err file (date patterns are allowed); if not set, errors will be printed only to PYTHON_WRAPPER_OUT_FILE
#       * PYTHON_WRAPPER_USE_STDOUT=1: 1 means to print usual messages to /dev/stdout too
#       * PYTHON_WRAPPER_USE_STDERR=1: 1 means to print error messages to /dev/stderr; otherwise will not be printed
#       *
#       *
#   3) execute venv/bin/python as always
#

#region replace actual python3.* with this script

if [ $# -eq 1 ] && [ -n "$1" ] && [ -e "$1/bin/python3" ]
then
    set -e

    pyexes=( $1/bin/python3.* )
    pyexe="${pyexes[0]}"

    if [ "$pyexe" == "$1/bin/python3.*" ]
    then
        echo "No python3.* found in $1/bin"
        exit 1
    fi

    if [ "${#pyexes[@]}" == "1" ] # check if not already replaced
    then
        mv "$pyexe" "${pyexe}_"
        umask 003
        cp "${BASH_SOURCE[0]}" "$pyexe"
    elif [ "${#pyexes[@]}" != "2" ] || [ "${pyexes[1]}" != "${pyexe}_" ]
    then
        echo "Different python3.* exist but seems like it is not the result of the actual operation: ${pyexes[@]}"
        exit 3
    fi

    if [ ! -x "$pyexe" ]
    then
        echo "wrapper is applied but is not executable, perform manually: chmod +x $pyexe"
        exit 3
    fi

    echo "wrapper is applied: $pyexe -> ${pyexe}_"

    exit 0
fi

#endregion

#region check whether replacement is already performed

pyexe="$(readlink -f "$0")_"
if [ ! -e "$pyexe" ]
then
    echo "wrapper is not applied"
    echo "firstly u need to perform something like: ./python.sh <path to venv>"
    echo "executed: $0 $*"
    exit 2
fi

#endregion

set -e

outfile="$(date +"${PYTHON_WRAPPER_OUT_FILE:?output file must be specified}")"
errfile="$(date +"${PYTHON_WRAPPER_ERR_FILE}")"

outfiles=( "$outfile" )
errfiles=( "$errfile" )
for i in {1..9}
do
    name="PYTHON_WRAPPER_SUPPLEMENT_OUT_FILE_$i"
    outfiles+=( "$(date +"${!name}")" )
    name="PYTHON_WRAPPER_SUPPLEMENT_ERR_FILE_$i"
    errfiles+=( "$(date +"${!name}")" )
done

function _log {
    local -
    set -e

    if [ -z "$1" ]
    then
        echo "saves message to log file and optionally prints to out/err descriptor"
        echo "usage: _log <message> <type=out>"
        return 0
    fi

    if [ $# -lt 1 ] || [ $# -gt 2 ]
    then
        echo "requires >=1,<=2 arguments, got $# ($@)!" &>/dev/stderr
        _log
        return 1
    fi

    local message="$1" kind="${2:-out}" day="$(date +"%Y-%m-%d")" time="$(date +"%T.%2N")"
    local record="$day $time [$BASHPID]: $message"

    local files=( ) file
    files+=("${outfiles[@]}")
    if [ "$kind" == "err" ] # in err print message to both err and out 
    then
        files+=("${errfiles[@]}")

        if [ "${PYTHON_WRAPPER_USE_STDERR:-1}" == "1" ]
        then
            echo "$record" > /dev/stderr
        fi
    elif [ "${PYTHON_WRAPPER_USE_STDOUT:-1}" == "1" ]
    then
        echo "$record"      
    fi

    for file in "${files[@]}"
    do
        if [ -n "$file" ]
        then
            mkdir -p "$(dirname "$file")"
            echo "$record" >> "$file"
        fi
    done
}

function _err-log {
    if [ -z "$1" ]
    then
        echo "saves message to make err.log file"
        echo "usage: _err-log <message>"
        return 0
    fi

    _log "$1" err
}

set +e

_log "executing: $0 $*"

"$pyexe" "$@"
rc=$?
m="exited with code: $rc"

if [ $rc -ne 0 ]
then
    _err-log "$m"
else
    _log "$m"
fi

exit $rc

