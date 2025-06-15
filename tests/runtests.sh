#!/bin/bash

#point shu urls to the local src folder
export SHU_GIT_REPO=$(realpath "..")
export SHU_COMMON_FOLDER_SOURCE="$SHU_GIT_REPO#src/libs/shu-common"

CreateHorizontalLine(){ local _char="${1:-"-"}"; local _print="${2:-true}"
    local _length=$(tput cols 2>/dev/null || echo 80)
    if [ -z "$_length" ] || [ "$_length" -le 0 ]; then
        _length=80
    fi

    _r=$(printf "%${_length}s" | tr ' ' "$_char")
    if [ "$_print" == "true" ]; then
        printf "%s\n" "$_r"
    fi
    return 0
}


CreateHorizontalLine "=" true
CreateHorizontalLine "=" true
CreateHorizontalLine "=" true
CreateHorizontalLine "=" true
CreateHorizontalLine "=" true

clear; 
../src/shu-cli.sh test -r
exit $?
