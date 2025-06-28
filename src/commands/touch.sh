#!/bin/bash

shu.Touch.Main(){
    echo "touch main called"
    if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
        shu.Touch.Help
        return 0
    fi

    if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
        _error="$ERROR_COMMAND_REQUIRES_SHU_PROJECT"
        return 1
    fi
    

    shu.Touch "$@"
    return $?
}

shu.Touch(){
    local addMain=false
    #check if some arg is '--addmain'
    if [[ "$@" == *"--addmain"* ]]; then
        addMain=true
        #remove --addmain from the arguments
        set -- "${@/--addmain/}"
    fi

    #if no arguments are given, print error and return
    if [ "$#" -eq 0 ]; then
        _error="No file name provided. Please provide a file name to create."
        return 1
    fi


    for fileName in "$@"; do

        #check if fileName contains .sh extensions
        if [[ "$fileName" != *.sh ]]; then
            fileName="$fileName.sh"
        fi

        if [ -f "$fileName" ]; then
            _error="File '$fileName' already exists. Please provide a different name."
            return 1
        fi

        local fileNameWithoutExt="${fileName%.*}"

        cp "$shu_scriptDir/assets/templates/samplesh.sh" "$fileName" 2>/tmp/shu-touch-error.log
        if [ $? -ne 0 ]; then
            _error="Error creating file '$fileName': $(cat /tmp/shu-touch-error.log)"
            rm /tmp/shu-touch-error.log
            return 1
        fi
        rm /tmp/shu-touch-error.log
        
        local miscImport='source "'$SHU_PROJECT_ROOT_DIR'.shu/packages/common/misc.sh"'
        #replace placeholders
        sed -i "s|%miscplaceholder%|$miscImport|g" "$fileName" 2>/dev/null
        sed -i "s|%fnameplaceholder%|$fileNameWithoutExt|g" "$fileName" 2>/dev/null

        chmod +x "$fileName"

        if [ "$addMain" == true ]; then
            shu.Main "mainfiles" "add" "$fileName"
            if [ "$_error" != "" ]; then
                _error="Error adding file '$fileName' to main section of shu.yaml: $_error"
                return 1
            fi
            echo "File '$fileName' added to main section of shu.yaml."
        fi
    done

    _error=""
    return 0
}

shu.Touch.Help(){
    echo "touch <fileName>         - Create a new script file with the given name. If no extension is provided, .sh will be added."
}

if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
    shu.Touch.Help
    return 0
fi

shu.Touch.Main "$@"
return $?
