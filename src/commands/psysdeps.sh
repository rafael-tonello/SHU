#!/bin/bash

shu.psysdeps.Main(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.psysdeps.Help
        return 0
    fi
    
    if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
        _error="$ERROR_COMMAND_REQUIRES_SHU_PROJECT"
        return 1
    fi
    

    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.psysdeps.$func" "$@"
}

shu.psysdeps.BashCompletion(){
    _r=("add" "remove" "list" "check")
}

shu.psysdeps.Help(){
    echo "psysdeps <subcommand>      - Informs system commands needed to project work correctly."
    echo "  subcommands:"
    echo "    add <commandName> [information] [options]"
    echo "                           - Add a command to the sysdepss section of shu.yaml."
    echo "      options:"
    echo "        --force, -f          - force to command to be added. It will override the existing (will update) command."
    echo "        --check-command, -c  - changes the way that shu check for dependency. Default way if using 'command -v <commandName>'"
    echo "    remove <commandName>   - Remove a command from the sysdepss section of shu.yaml."
    echo "    list [options]         - List all commands in the sysdepss section of shu.yaml."
    echo "      options:"
    echo "        --level, -l <level>  - specify the level of dependencies to scan. default is 0 (no limits)"
    echo "                               examples:"
    echo "                                 |-0 - all dependencies of all packages and the current project;"
    echo "                                 |-1 - only the current project;"
    echo "                                 |-2 - current project and its dependencies;"
    echo "                                 |-3 - current project and its dependencies and their dependencies, etc;"
    echo "                                 |-N - current project and its dependencies and their dependencies and so on, up to N levels;"
    echo "        --onlynames, -on     - only show the names of the dependencies"
    echo "    check [options]        - Check if the commands in the sysdepss section of shu.yaml are available in the system."
    echo "      options:"
    echo "        --level, -l <level>  - specify the level of dependencies"
}

#add a command depenency to the project.
#
#You can:
#   shu psysdeps add <command> <information>  add a command dependency with the given command name 
#                                           and information
#
#   shu psysdeps add <command1> <information1> <command2> <information2> ... 
#                                           add multiple command dependencies with the given command 
#                                           names and information
#
#   shu psysdeps add <command1:information1> <command2:information2> ... -> 
#                                           add multiple command dependencies with the given command
#                                           names and information, where each command is a key-value
#                                           pair separated by ':' or '='
#
#You cannot do:
#   shu psysdeps add <command1> <command2>    Mistake. Will use command2 as information for command1, 
#                                           which is not what you want.
shu.psysdeps.Add(){
    if [ "$#" -eq 0 ]; then
        _error="No command name provided. Please provide a command name to add."
        return 1
    fi
    shu.initFolder

    local command="$1";
    local information="$2"
    shu.getValueFromArgs_manyNames "--check-command -c" "command -v $command" "$@"; local _checkCommand="$_r"
    shu.getValueFromArgs_manyNames "--force -f" false "$@"; local forceUpdate="$_r"
    
    
    shu._sysdepsadd "$command" "$information" "$_checkCommand" $forceUpdate
    if [ "$_error" != "" ]; then
        _error="Error adding command '$command': $_error"
        return 1
    fi

    if _r="updated"; then
        echo "Command '$command' updated in sysdepss section of shu.yaml."
    else
        echo "Command '$command' added to sysdepss section of shu.yaml."
    fi

    #recursive call for remain arguments
    if [ "$#" -gt 0 ]; then
        shu.psysdeps.Add "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi

    _r=""
    _error=""
    return 0    
}


#Check if commands are available in the system.
#Ipmortant, should scan all from dependencies (or use --level, -l to specify the level of dependencies to scan)
#User sysdepslist to get litst
shu.psysdeps.Check(){
    shu.getValueFromArgs_manyNames "--level -l" "0" "$@"; local level="$_r"

    echo "Checking system commands dependencies for your project:"

    checkFoundDeps=0
    local missing=()
    __f(){ local cmdName="$1"; local description="2"; local cmdCheckCommand="$3"
        checkFoundDeps=$((checkFoundDeps +1 ))
        printf "    checking $cmdName: "
        eval "$cmdCheckCommand" &> /dev/null; local cmdCheckStatus="$?"
        
        if [ "$cmdCheckStatus" -eq 0 ]; then
            #green message 
            echo -e "\e[32mok\e[0m"
        else
            #red message
            echo -e "\e[31mmissing\e[0m"
            missing+=("$dep")
        fi
        
    };
    shu.psysdeps._list __f $level

    if [ "$checkFoundDeps" -eq 0 ]; then
        echo "No system commands dependencies found."
        return 0
    fi

    echo ""
    if [ "${#missing[@]}" -ne 0 ]; then
        echo "The following commands are missing:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        
    else
        echo "All commands are available."
    fi
}

#remove a command dependency from the project.
#Note: it cannot remove a command dependency form dependencies, only from the main project.
shu.psysdeps.Remove(){ local command="$1"; shift
    if [ "$command" == "" ]; then
        _error="No command name provided. Please provide a command name to remove from sysdepss section."
        return 1
    fi

    shu.initFolder

    #check if command is in the sysdepss section of shu.yaml
    shu.getsysdepsIndex "$command"; local index="$_r"
    if [ "$index" == "-1" ]; then
        _error="Command '$command' is not in the sysdepss section of shu.yaml. Please provide a valid command name."
        return 1
    fi

    #remove command from the sysdepss section
    shu.yaml.removeArrayElement "shu.yaml" ".sysdepss" "$index"
    if [ "$_error" != "" ]; then
        _error="Error removing command '$command' from sysdepss section of shu.yaml: $_error"
        return 1
    fi

    echo "Command '$command' removed from sysdepss section of project '$SHU_PROJECT_NAME'."
    _error=""

    #recursive call for remain arguments
    if [ "$#" -ne 0 ]; then
        shu.psysdeps.Remove "$@"
        return $?
    fi
}

#returns _r with 'updated' if command was updated, or empty string if command was added
shu._sysdepsadd(){ local command="$1"; local information="$2"; local checkCommand="$3"; local _forceUpdate="${4:-false}"
    if [ "$command" == "" ]; then
        _error="No command name provided. Please provide a command name to add to sysdepss section."
        return 1
    fi

    #check if command is already in the sysdepss section of shu.yaml
    #sysdepss is a object, where the key is the command name and the value is the information about the command
    shu.getsysdepsIndex "$command"; local index="$_r"
    if [ "$index" != "-1" ]; then
        #check if there is --force or -f in the arguments
        if $_forceUpdate; then
            shu.yaml.removeArrayElement "shu.yaml" ".sysdepss" "$index"
            if [ "$_error" != "" ]; then
                _error="Error updating command '$command' from sysdepss section of shu.yaml: $_error"
                return 1
            fi
        else
            _error="Command '$command' is already in the sysdepss section of shu.yaml. Please provide a different command name."
            return 1
        fi
    fi
    

    if [ "$information" == "" ]; then
        information="No information provided."
    fi

    shu.yaml.appendObjectToArray "shu.yaml" ".sysdepss" "cmd:$command" "info:$information" "check-command:$checkCommand"> /dev/null 2>&1
    if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
        _error="Error adding command '$command' to sysdepss section of shu.yaml: $_error"
        return 1
    fi

    error=""
    _r=""
    if [ "$_forceUpdate" == "true" ]; then
        _r="updated"
    fi

    return 0
}

#List necessary commands for the project. List sysdepss from current project and from its dependencies, and dependencies of dependencies, etc.
#Ipmortant, should scan all from dependencies (or use --level, -l to specify the level of dependencies to scan)#
#sysdepslist [options]
#Options:
#   --level, -l <level>  : specify the level of dependencies to scan (default: 0):
#                           0 - all dependencies of all packages and the current project,
#                           1 - only the current project, 
#                           2 - current project and its dependencies, 
#                           3 - current project and its dependencies and their dependencies, etc.
#                           N - current project and its dependencies and their dependencies and so on, up to N levels.
#   --names, -n          : only show the names of the dependencies
shu.psysdeps.List(){
    shu.getValueFromArgs_manyNames "--level -l" "1" "$@"; local level="$_r"
    shu.getValueFromArgs_manyNames "--onlynames -on" false "$@"; local onlyNames="$_r"  

    local toPrint=()
    local foundCmds=();


    __f(){ local cmdName="$1"; local description="2"; local cmdCheckCommand="$3"
        #check if command is already found {
            local cmdIndex=$(printf "%s\n" "${cmdDesc[@]}" | grep -n -x -F "$cmdName" | cut -d: -f1)
            cmdIndex=$((cmdIndex - 1)) #convert to zero-based index

            if [[ "$cmdIndex" != "" && "$cmdIndex" != "-1" ]]; then
                #if cmdName is already in foundCmds, add description to the existing command
                if [ "$onlyNames" == "false" ]; then
                    #add description to the existing command
                    toPrint[$cmdIndex]="${toPrint[$cmdIndex]} + $cmdDesc (with $cmdCheckCommand)"
                fi

                continue
            fi
        #}

        foundCmds+=("$cmdName")

        if [ "$onlyNames" == "false" ]; then
            #append the command name and description to the ret array
            toPrint+=("$cmdName: $cmdDesc (with $cmdCheckCommand)")
        else
            toPrint+=("$cmdName")
        fi
    
    }; 
    shu.psysdeps._list __f $level
}

#scroll through current folder and its subfolders (if allowNotShuSubFolders is true) and looks for shu.yaml files.
#For each shu.yaml file, it will get the sysdepss section and return the list of commands in the sysdepss section.
shu.psysdeps._list(){ local callback="$1"; local maxLevel="$2"

    if [ -f './shu.yaml' ]; then
        local index=-1
        while true; do
            index=$((index + 1))
            shu.yaml.getObjectFromArray "shu.yaml" ".sysdepss" "$index";
            
            if [ "$_error" == "$ERROR_INDEX_OUT_OF_BOUNDS" ]; then
                _error=""
                break;
            fi

            declare -A psysdeps
            for k in "${!_r[@]}"; do
                psysdeps["$k"]="${_r[$k]}"
            done

            if [ "$_error" != "" ]; then
                _error="Error getting sysdepss from shu.yaml: $_error"
                return 1
            fi

            local cmdName=${psysdeps["cmd"]}
            local cmdDesk=${psysdeps["info"]}
            local cmdCheckCommand=${psysdeps["check-command"]}

            
            eval "$callback \"$cmdName\" \"$cmdDesk\" \"$cmdCheckCommand\""
        done
    fi

    #list current folder subfolders
    local subFolders=$(find . -mindepth 1 -maxdepth 1 -type d)
    for subFolder in $subFolders; do
        #count how much .shu folders are in the path
        local shuCount=$(echo "$subFolder" | grep -o "\.shu" | wc -l)
        #if shuCount is greater or equals to maxLevel, skip this folder
        if [ "$shuCount" -ge "$maxLevel" ] && [ "$maxLevel" -gt 0 ]; then
            continue
        fi

        #check if current folder is '.shu' or allowNotShuSubFolders="true"
        if [ "$subFolder" == "./.shu" ]; then
            shu.psysdeps.List "$callback" "$maxLevel"
            if [ "$_error" != "" ]; then
                _error="Error listing sysdepss in subfolder '$subFolder': $_error"
                return 1
            fi

            #append the result to ret
            for index in "${!_r[@]}"; do
                local foundCmd="$_r_foundCmds[$index]"
                if [[ ! " ${foundCmds[@]} " =~ " $foundCmd " ]]; then
                    foundCmds+=("$foundCmd")
                    ret+=("${_r[$index]}")
                fi
            done

            unset _r
            unset _r_foundCmds
        fi
    done

    _error=""
    _r=("${ret[@]}")
    _r_foundCmds=("${foundCmds[@]}")
    return 0
}

shu.getsysdepsIndex(){ local command="$1"
    #get the index of the command in the sysdepss section of shu.yaml
    local index=0;
    while true; do
        shu.yaml.getObjectFromArray "shu.yaml" ".sysdepss" "$index"
        declare -A psysdeps
        for k in "${!_r[@]}"; do
            psysdeps["$k"]="${_r[$k]}"
        done

        if [ "$_error" == "$ERROR_INDEX_OUT_OF_BOUNDS" ]; then
            _error=""
            break;
        fi

        local cmdName=${psysdeps["cmd"]}
        if [ "$cmdName" == "$command" ]; then
            _error=""
            _r="$index"
            return 0
        fi

        index=$((index + 1))
    done

    _error=""
    _r="-1"
    return 0
}

shu.psysdeps.Main "$@"; local retCode="$?"
return $retCode
