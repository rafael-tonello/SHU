#!/bin/bash

#pcommand are commands for the proejct
#when user enter a shu command, the first place when it are looked for is the pcommands
#pcommand is a short for 'project command'

shu.pcommand.main(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.pcommand.Help
        return 0
    fi
    
    if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
        _error="$ERROR_COMMAND_REQUIRES_SHU_PROJECT"
        return 1
    fi
    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift

    "shu.pcommand.$func" "$@"
    return $?
}

shu.pcommand.Help(){
    echo "pcommand <subcommand>    - Commands to manage dependencies of the project"
    echo "  subcommands:"
    echo "    add <name> <command> <description>"
    echo "                           - Add a new command to the project. When you run 'shu <name>', the bash command <command> will be executed. All arguments will be passed to the command. When you run 'shu --help', the <discription> will be shown as description of the command. <name>, <command> and <description> are required parameters." 
    echo "    list                   - List all project commands."
    echo "    remove <command>       - Removes the project the project command <command>."
    echo "    run  <command> [args]  - Runs the command <command> and pass [args] to it. Is the same as running 'shu <command> [args]'."
}

shu.pcommand.Add(){
    local name="$1"
    local command="$2"
    local description="$3"
    shift 3

    shu.yaml.set "shu.yaml" ".project-commands.$name.bash-action" "$command"
    if [ ! -z "$_error" ]; then
        _error="Failed to add project command '$name': $_error"
        return 1
    fi
    
    shu.yaml.set "shu.yaml" ".project-commands.$name.description" "$description"
    if [ ! -z "$_error" ]; then
        _error="Failed to add project command '$name': $_error"
        return 1
    fi

    shift 2
    if [[ $# -gt 0 ]]; then
        shu.pcommand.Add "$@"
        return $?
    fi

    _error=""
    return 0
}


#if callback is provided, it will be called with the command name, action and description as arguments.
#If no callback is provided, the commands will be printed to the console.
shu.pcommand.List(){ local _callback="${1:-}"
    shu.yaml.listProperties "shu.yaml" ".project-commands"; local commands=("${_r[@]}")

    for command in "${commands[@]}"; do
        shu.yaml.get "shu.yaml" "project-commands.$command.bash-action"; local commandAction="$_r"
        if [ ! -z "$_error" ]; then _error="Failed to get project command '$command': $_error"; return 1; fi

        shu.yaml.get "shu.yaml" "project-commands.$command.description"; local description="$_r"
        if [ ! -z "$_error" ]; then _error="Failed to get project command '$command': $_error"; return 1; fi

        if [ -z "$_callback" ]; then
            echo "$command (runs '$commandAction'): $description"
        else
            
            eval "$_callback \"\$command\" \"\$commandAction\" \"\$description\""
        fi
    done
}

shu.pcommand.Remove(){
    local command="$1"

    shu.yaml.remove "shu.yaml" ".project-commands.$command"
    if [[ $? -ne 0 ]]; then
        _error="Failed to remove project command '$command'."
        return 1
    fi

    if [[ $# -gt 0 ]]; then
        shu.pcommand.Remove "$@"
        return $?
    fi

    _error=""
    return 0
}

shu.pcommand.Run(){
    local command="$1"
    shift

    shu.yaml.get "shu.yaml" ".project-commands.$command.bash-action"; local commandAction="$_r"
    if [ ! -z "$_error" ]; then
        _error="Failed to get project command '$command': $_error"
        return 1
    fi

    shu.yaml.get "shu.yaml" ".project-commands.$command.description"; local description="$_r"
    if [ ! -z "$_error" ]; then
        _error="Failed to get project command '$command' description: $_error"
        return 1
    fi

    eval "$commandAction \"$@\"" 2>/tmp/shu-pcommand-run-error.log; __retCode=$?
    local retCode=$__retCode
    if [[ $retCode -ne 0 ]] || [[ "$_error" != "" ]]; then
        if [ ! -z "$_error" ]; then
            _error="Failed to run project command '$command': $_error"
        else
            _error="Failed to run project command '$command'"
        fi

        if [ -f "/tmp/shu-pcommand-run-error.log" ]; then
            _error="$_error + $(cat /tmp/shu-pcommand-run-error.log)"
            rm -f /tmp/shu-pcommand-run-error.log
        fi

        return 1
    fi
    return $retCode
}


shu.pcommand.main "$@"
return $?
