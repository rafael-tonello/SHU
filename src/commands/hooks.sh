#!/bin/bash

shu.Hooks.Main(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.Hooks.Help
        return 0
    fi


    if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
        _error="$ERROR_COMMAND_REQUIRES_SHU_PROJECT"
        return 1
    fi

    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.Hooks.$func" "$@"
    return $?
}

shu.Hooks.BashCompletion(){
    _r=("add" "remove" "list")
}

shu.Hooks.Help(){
    echo "hooks <subcommand>        - Manage hooks for shu commands. Is focused in automating the project. A hooks runs commands before or after a shu command be executed (including those ones created for your project. See 'shu pcommand --help' for more information)."
    echo "  subcommands:"
    echo "    add <when> <shu-command> <command>"
    echo "                             - Add a new hooks than executes <command> <when> <shu-command>. <command> is a shu command without the 'shu' prefix. For example, 'add before build' will add a hooks that executes 'build' command before the <shu-command> is executed. <command> is a bash command. You can specify commands directly or use a script file. If you want to use a script, and want that this script have access to shu memory context, you should use 'source <your script>' instead of '<your script.sh>. The <when> can be 'after' or 'before' (more information below)."
    echo "      when:                  - Sepcify when, relative to the shu command, the hooks should be executed."
    echo "        before                 - hooks should be executed before the <shu-command> be executed. If return code is not 0, the <shu-command> will not be executed."
    echo "        after                  - hooks should be executed after the <shu-command> be executed."
    echo "      shu-command:           - The shu command that will trigger the hooks. It a command, that shu is running, starts with this shu-command, the hooks will be executed."
    echo "      command:               - The command to be executed when the hooks is triggered. It can be a bash command or a script file. If it is a script file, you should use 'source <your script>' to have access to shu memory context. Before a hooks be executed, shu export some variables that can be used in you command/script:"
    echo "                                |-1) SHU_HOOK_INDEX: the index of the hooks in the list of hooks."
    echo "                                |-2) SHU_HOOK_WHEN: when the hooks is execute (before or after) in relation to the shu command."
    echo "                                |-3) SHU_HOOK_COMMAND_TO_RUN: the hooks commnad (your code)."
    echo "                                |-4) SHU_HOOK_COMMAND_TO_CHECK: the shu command that should be evaluated."
    echo "                                |-5) SHU_HOOK_RECEIVED_COMMAND: the command that is being executed (the command that shu is running)."

    echo "    list [callback]        - List all hooks in the project."
    echo "      callback:             - If provided, the callback will be called for each hooks with the following arguments: <index> <when> <shu-command> <command>. If not provided, the hooks will be printed to the console."
    echo "    remove <index>         - Remove a hooks by its index from the list of hooks."
}

#add a hooks to the project.
shu.Hooks.Add(){
    if [ "$#" -eq 0 ]; then
        _error="No hoock name provided. Please provide a command name to add."
        return 1
    fi
    
    local when="$1";
    local shucommand="$2"
    local command="$3"
    
    if [[ "$when" != "after" && "$when" != "before" ]]; then
        _error="Invalid when argument '$when'. It should be 'after' or 'before'."
        return 1
    fi

    if [[ "$shucommand" == "" ]]; then
        _error="No shu command provided. Please provide a shu command to add."
        return 1
    fi

    if [[ "$command" == "" ]]; then
        _error="No command provided. Please provide a command to add."
        return 1
    fi

    #replace all spaces in command with '-' in shu-command

    shu.yaml.appendObjectToArray "shu.yaml" ".hooks" "when:$when" "shu-command:$shucommand" "cmd:$command"
    if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
        _error="Error adding hooks '$when \"$shucommand\" \"$command\"' to shu.yaml: $_error"
        return 1
    fi

    #recursive call for remain arguments
    shift 3
    if [ "$#" -gt 0 ]; then
        shu.Hooks.Add "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi

    _r=""
    _error=""
    return 0    
}

#List hooks in the project.
#if _callback is provided, it will be called for each hooks and nohing will be printed to the console (instead in case of errors).
#callback is called with the following arguments:
#  - index: the index of the hooks in the list
#  - when: the when of the hooks (before or after)
#  - shucommand: the shu command of the hooks
#  - command: the command of the hooks
#if callback returns an error (return a code != 0 or setting _error variable), the error will be printed to the console and the function will return 1.
shu.Hooks.List(){ local _callback="${1:-}"; shift
    _error=""

    local index=-1
    local results=()
    while true; do
        index=$((index + 1))
        shu.yaml.getObjectFromArray "shu.yaml" ".hooks" "$index"
        declare -A hooks
        #_r is an associative array with the hooks properties
        for k in "${!_r[@]}"; do
            hooks["$k"]="${_r[$k]}"
        done
        unset _r


        if [ "$_error" == "$ERROR_INDEX_OUT_OF_BOUNDS" ]; then
            _error=""
            break;
        fi

        if [ "$_error" != "" ]; then
            _error="Error getting hooks from shu.yaml: $_error"
            return 1
        fi
        
        local when=${hooks["when"]}
        local shucommand=${hooks["shu-command"]}
        local command=${hooks["cmd"]}


        if [ -z "$_callback" ]; then
            results+=("$index) $when '$shucommand' runs '$command'")
        else
            _error=""
            eval "$_callback \"$index\" \"$when\" \"\$shucommand\" \"\$command\"" 2>/tmp/shu-hooks-error.log
            if [ $? -ne 0 ] || [ "$_error" != "" ]; then
                if [ "$_error" != "" ]; then
                    _error="Error in callback for hooks '$index) $when \"$shucommand\" runs \"$command\"': $_error"
                    if [ -f "/tmp/shu-hooks-error.log" ]; then
                        _error="$_error + $( cat /tmp/shu-hooks-error.log 2>/dev/null )"
                    fi
                elif [ -f "/tmp/shu-hooks-error.log" ]; then
                    _error="Error in callback for hooks $(cat /tmp/shu-hooks-error.log 2>/dev/null)"
                fi

                rm -f /tmp/shu-hooks-error.log
                return 1
            fi
        fi
    done

    if [ -z "$_callback" ]; then
        cd "$retFolder"
        for item in "${results[@]}"; do
            echo "$item"
        done
    fi

    _error=""
    _r=""
    return 0
}

#Removes a hooks from the project.
shu.Hooks.Remove(){ local index="$1"; shift
    # Load the existing properties from shu.yaml
    if [ ! -f "shu.yaml" ]; then
        shu.printError "shu.yaml file not found."
        return 1
    fi

    shu.yaml.removeArrayElement "shu.yaml" ".hooks" "$index"
    if [ "$_error" != "" ]; then
        _error="Error removing command hooks from shu.yaml: $_error"
        return 1
    fi

    echo "hooks removed from project '$SHU_PROJECT_NAME'."
    _error=""

    #recursive call for remain arguments
    if [ "$#" -ne 0 ]; then
        shu.Hooks.Remove "$@"
        return $?
    fi
}

#run a hooks command if a registered hooks have its 'when' property equals to '$when' and its 'shu-command' property starts with '$shuCommand'.
shu.Hooks.Run(){ local rwhen="$1"; shift; local rcommandToCheck="$@"
    if [[ "$rwhen" != "after" && "$rwhen" != "before" ]]; then
        _error="Invalid when argument '$rwhen'. It should be 'after' or 'before'."
        return 1
    fi

    if [[ "$rcommandToCheck" == "" ]]; then
        _error="No shu command provided. Please provide a shu command to run."
        return 1
    fi
    

    found=false
     __f(){ local _index="$1"; local _when="$2"; local _shuCommandMask="$3"; local _hookCommand="$4";
        if [[ "$_when" == "$rwhen" ]] && [[ "$rcommandToCheck" == "$_shuCommandMask"* ]]; then
            local shortenedHookCommandString="${_hookCommand:0:100}"
            if [[ "${#_hookCommand}" -gt 100 ]]; then
                shortenedHookCommandString+="..."
            fi

            echo "$(shu.printGreen "Running hook") $_index: $_when $_shuCommandMask -> $shortenedHookCommandString"

            found=true
            cd "$projectRoot"
            export SHU_HO OK_INDEX="$_index"
            export SHU_HOOK_WHEN="$_when"
            export SHU_HOOK_COMMAND_TO_RUN="$_hookCommand"
            export SHU_HOOK_COMMAND_TO_CHECK="$commandToCheck"
            export SHU_HOOK_RECEIVED_COMMAND="$commandToCheck"

            #TODO: somethimes, a hook command comes with ' '. Find what is the problem and removes the if bellow
            if [[ "$_hookCommand" == "" || "$_hookCommand" == " " ]]; then
                return 0
            fi


            eval "$_hookCommand 2>/tmp/shu-hooks-error.log"; __retCode=$?

            local tmpErr=""
            if [ -f /tmp/shu-hooks-error.log ]; then
                while read -r line; do
                    if [ "$tmpErr" != "" ]; then
                        tmpErr+=" + "
                    fi
                    tmpErr+="$line"
                done < /tmp/shu-hooks-error.log
                rm -f /tmp/shu-hooks-error.log > /dev/null 2>&1

                if [ "$_error" != "" ]; then
                    _error="$_error + $tmpErr"
                else
                    _error="$tmpErr"
                fi
            fi

            if [ $__retCode -ne 0 ] || [ "$_error" != "" ]; then
                if [ "$_error" != "" ]; then
                    _error="Error in callback for hooks: $_error"
                else
                    _error="Error in callback for hooks: Unknown error"
                fi
                return 1
            fi
        fi
    };
    shu.Hooks.List "__f"

    if [ "$found" = false ]; then
        _error="$ERROR_NO_HOOKS_FOUND"
        return 1
    fi

    if [ "$_error" != "" ]; then
        _error="Error running hooks for '$rwhen $rcommandToCheck': $_error"
        return 1
    fi

    _r=""
    _error=""
}

shu.Hooks.Main "$@"; local retCode="$?"
return $retCode
