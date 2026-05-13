#!/bin/bash

#
# wrapper on some venv/bin/python executable which logs command start and exit
# 
# usage:
#   1) replace existing python with this script using: ./python.sh <path to venv>
#   2) specify next environment variables:
#       *
#       *
#       *
#       *
#       *
#       *
#   3) execute venv/bin/python as always
#

#region replace actual python3.* with this script

if [ $# -eq 1 ] && [ -n "$1" ] && [ -e "$1/bin/python3" ]
then
    set -e

    pyexe="$(echo $1/bin/python3.*)"
    if [ "$pyexe" == "$1/bin/python3.*" ]
    then
        echo "No python3.* found in $1/bin"
        exit 1
    fi

    mv "$pyexe" "${pyexe}_"

    umask 003
    cp "${BASH_SOURCE[0]}" "$pyexe"
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




"$pyexe" "$@"


