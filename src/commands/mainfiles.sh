#!/bin/bash

shu.MainFiles.Main(){
    if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help" ]]; then
        shu.MainFiles.Help
        return 0
    fi

    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.MainFiles.$func" "$@"
}

shu.MainFiles.BashCompletion(){
    _r=("add" "remove" "list" "run")
}

#add a script to the main section of shu.yaml
shu.MainFiles.Add(){ local scriptName="$1"; shift
    if [ "$scriptName" == "" ]; then
        _error="No script name provided. Please provide a script name to set as main."
        return 1
    fi
    shu.initFolder
    
    #check if script exists
    if [ ! -f "$scriptName" ]; then
        _error="Script '$scriptName' not found. Please provide a valid script name."
        return 1
    fi
    #check if script is executable
    if [ ! -x "$scriptName" ]; then
        _error="Script '$scriptName' is not executable. Please make it executable with 'chmod +x $scriptName'."
        return 1
    fi
    
    #check if file is already added to the 'main' section of shu.yaml (user shu.yaml.arrayContains)
    shu.yaml.arrayContains "shu.yaml" ".main" "$scriptName"
    if [ "$_r" == "true" ]; then
        _error="Script '$scriptName' is already set as main. Please provide a different script name."
        return 1
    fi

    #add script to the main section
    shu.yaml.addArrayElement "shu.yaml" ".main" "$scriptName"
    if [ "$_error" != "" ]; then
        _error="Error adding script '$scriptName' to main section of shu.yaml: $_error"
        return 1
    fi

    echo "Script '$scriptName' set as a main script for project '$SHU_PROJECT_NAME'."

    #recursive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.MainFileAdd "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi

    _error=""
    return 0
}

#runs the [scriptName]. If no script name is provided, it will run all scripts in the main section of shu.yaml.
shu.MainFiles.Run(){ local scriptName="$1"; shift
    #yellow warning

    shu.initFolder
    if [ "$scriptName" != "" ]; then
        shu.runScript "$scriptName" "$@"
        if [ "$_error" != "" ]; then
            shu.printError "Shu error: $_error"
            return 1
        fi
    else
        #fun all files specified in the main list of shu.yaml
        shu.yaml.getArray "shu.yaml" ".main[]"; local mainScripts=("$_r")
        if [ "$mainScriptList" == "" ]; then
            _error="This project has no main scripts defined yet. User 'shu setmain <scriptName>' to set a script as main or run 'shu run <scriptName>' to run a specific script."
            return 1
        fi

        for script in $mainScriptList; do
            shu.runScript "$script" "$@"
            if [ "$_error" != "" ]; then
                shu.printError "Shu error: $_error"
            fi
        done
    fi      

    #recursive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.Mainfilerun "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi

    _error=""
    return 0
}

shu.MainFiles.Remove(){ local scriptName="$1"; shift
    echo "Removing script from main section of shu.yaml: $scriptName"
    if [ "$scriptName" == "" ]; then
        _error="No script name provided. Please provide a script name to remove from main section."
        return 1
    fi
    shu.initFolder

    #check if script is in the main section of shu.yaml
    shu.Mainfiles.getMainFileIndex "$scriptName"; local index="$_r"
    if [ "$_index" == "-1" ]; then
        _error="Script '$scriptName' not found in the main section of shu.yaml. Please provide a valid script name."
        return 1
    elif [ "$_error" != "" ]; then
        _error="Error getting main script index: $_error"
        return 1
    fi

    #remove script from the main section
    shu.yaml.removeArrayElement "shu.yaml" ".main" "$index"

    #recursive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.MainFileRemove "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
}

shu.MainFiles.List(){
    shu.initFolder

    #get all main scripts from shu.yaml
    shu.yaml.getArray "shu.yaml" ".main[]"; local mainScripts=("${_r[@]}")
    if [ "$_error" != "" ]; then
        _error="Error getting main scripts from shu.yaml: $_error"
        return 1
    fi

    if [ "${#mainScripts[@]}" -eq 0 ]; then
        echo "No main scripts set in the project."
        return 0
    fi

    for script in "${mainScripts[@]}"; do
        echo "$script"
    done
}

shu.Mainfiles.getMainFileIndex(){ local scriptName="$1"; shift
    shu.yaml.getArray "shu.yaml" ".main[]"; local mainScripts=("${_r[@]}")
    echo "mainScripts: ${mainScripts[@]}"

    if [ "$_error" != "" ]; then
        _error="Error getting main scripts from shu.yaml: $_error"
        _r="-1"
        return 1
    fi


    for i in "${!mainScripts[@]}"; do
        if [ "${mainScripts[$i]}" == "$scriptName" ]; then
            _r="$i"
            return 0
        fi
    done
    
    _r="-1"
    _error="Script '$scriptName' not found in the main section of shu.yaml."
    return 1
}

shu.runScript(){ local scriptName="$1"; shift
    if [ -f "$scriptName" ]; then
        #check if script is executable
        if [ ! -x "$scriptName" ]; then
            _error="Script '$scriptName' is not executable. Please make it executable with 'chmod +x $scriptName'."
            return 1
        fi
        #run the script
        "./$scriptName" "$@"
        return $?
    else
        _error="Script '$scriptName' not found."
        return 1
    fi

    #recursive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.runScript "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
}

shu.MainFiles.Help(){
    echo "mainfile <subcommand>    - Commands to manage main scripts of the project"
    echo "  subcommands:"
    echo "    add <scriptNames>...     - Add scripts to the main section of shu.yaml."
    echo "    remove <scriptNames>..."
    echo "                             - Remove scripts from the main section of shu.yaml."
    echo "  list                     - List all scripts in the main section of shu.yaml."
}

shu.MainFiles.Main "$@"
return $?
