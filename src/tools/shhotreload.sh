#!/bin/bash

shellscriptdev(){
    #if no args or help
    if [ "$#" -lt 1 ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        echo "Usage: shellscriptdev <file> [<runBefore>] [<runAfter>] [adicional] [file] [names]"
        return 1
    fi

    local shFile="$1"
    local runBefore="$2"
    local runAfter="$3"
    local fileNames=("${@:4}")
    local fileNames+=("$shFile")
    local lastChangeTimes=()

    
    while true; do
        local fire=false
        local tmpNewChangeTimes=()
        for i in "${!fileNames[@]}"; do
            local fileName="${fileNames[$i]}"
            local newChangeTime=$(stat -c %Y "$fileName")
            local lastChangeTime=${lastChangeTimes[$i]}
            
            if [ "$newChangeTime" != "$lastChangeTime" ]; then
                fire=true
            fi

            tmpNewChangeTimes+=("$newChangeTime")
        done

        lastChangeTimes=("${tmpNewChangeTimes[@]}")
        unset tmpNewChangeTimes
        if [ "$fire" == "true" ]; then
            if [ "$runBefore" != "" ]; then
                eval "$runBefore"
            fi

            #run the script
            bash "$shFile"

            if [ "$runAfter" != "" ]; then
                eval "$runAfter"
            fi
        fi
            sleep 0.5
    done
}

shellscriptdev "$@"
