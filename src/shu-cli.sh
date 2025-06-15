#!/bin/bash

SHU_VERSION="0.0.0"
shu_scriptFullPath="$(realpath "$0")"
shu_scriptDir="$(dirname "$shu_scriptFullPath")"



#Common errors
    ERROR_AREADY_DONE="already done"
    ERROR_NO_SHU_DIRECTORY="is not shu project/directory. No shu.yaml found"
    ERROR_INDEX_OUT_OF_BOUNDS="index out of bounds"
#}

#shu values that can be overridden by environment variables {
    if [ -z "$SHU_GIT_REPO" ]; then SHU_GIT_REPO="https://github.com/rafael-tonello/SHU.git"; fi
    if [ -z "$SHU_COMMON_FOLDER_SOURCE" ]; then SHU_COMMON_FOLDER_SOURCE="$SHU_GIT_REPO#src/libs/shu-common"; fi
#}

shu.main(){ local cmd="$1";

    if [[ "$cmd" == "-h" || "$cmd" == "--help"  || $# -eq 0 ]]; then
        shu.Help
        return 0
    elif [[ "$cmd" == "-v" || "$cmd" == "--version" ]]; then
        echo "Shu CLI version $SHU_VERSION"
        return 0
    fi
    shift;

    shu.checkPrerequisites
    if [ "$_error" != "" ]; then
        shu.printError "Shu error: $_error"
        return 1
    fi

    local capitalizedCmd=$(echo "$cmd" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    _error=""
    
    #check if project contains the command
    shu.Pcommandexists "$cmd"; local exists="$_r"
    if [ "$exists" == "true" ]; then
        #run the command from the project
        shu.Pcommandrun "$cmd" "$@"; local retCode=$?
        if [ "$_error" != "" ]; then
            shu.printError "Shu error: $_error"
        fi 
        return $retCode
    fi

    local retCode=0
    #check if lowercase of capitalizedCmd contains 'Run' or 'run' (do not supress stderr when running scripts using shu)
    if [[ "$capitalizedCmd" == *"Run"* ]]; then
        shu.Run "$@"
        retCode=$?
    elif type "shu.$capitalizedCmd" &> /dev/null; then
        shu.$capitalizedCmd "$@"
        retCode=$?

        if [ "$_error" != "" ]; then
            shu.printError "Shu error: $_error"
        fi
        return $retCode
    else
        #check if the folder $shu_scriptFullPath/.shu/packages/shu-common/commands/$cmd.sh exists
        local commandFile="$shu_scriptDir/commands/$cmd.sh"
        if [ -f "$commandFile" ]; then
            #run the command file
            source "$commandFile" "$@"
            retCode=$?
            if [ "$retCode" -ne 0 ]; then
                if  [ -f /tmp/shu_error.log ]; then
                    _error="$_error. $(cat /tmp/shu_error.log)"
                fi

                shu.printError "Shu error: Error running command '$cmd': $_error"
                rm -f /tmp/shu_error.log
            fi
            rm -f /tmp/shu_error.log
            return $retCode
        else
            shu.printError "Command '$cmd' not found in your project, nor in the SHU commands. User 'shu pcommand --help' to see the available project commands, or 'shu --help' to see the available SHU commands."
            retCode=1
        fi

    fi
    
    return 0
}

shu.checkPrerequisites(){

    #check if yq is installed
    if ! command -v yq &> /dev/null; then
        _error="yq is not installed. Please install yq to use Shu (go install github.com/mikefarah/yq/v4@latest). Read more in https://github.com/mikefarah/yq"
        return 1
    fi

    #check git
    if ! command -v git &> /dev/null; then
        _error="git is not installed. Please install git to use Shu."
        return 1
    fi

    if ! command -v split &> /dev/null; then
        _error="split is not installed. Please install split to use Shu."
        return 1
    fi

    ##check if jq is installed
    #if ! command -v jq &> /dev/null; then
    #    _error="jq is not installed. Please install jq to use Shu."
    #    return 1
    #fi

    return 0
}

shu.printRed(){ local message="$1"; local keepOpened="${2:-}"
    printf "\033[0;31m$message"
    if [ "$keepOpened" != "true" ]; then
        printf "\033[0m"
    fi
}

shu.printGreen(){ local message="$1"; local keepOpened="${2:-}"
    printf "\033[0;32m$message"
    if [ "$keepOpened" != "true" ]; then
        printf "\033[0m"
    fi
}

shu.printError(){
    local errorMessage="$1";
    local _allLinesPrefix="${2:-""}"; 
    local _beginLineText="${3:-"⤷ "}"; 
    local _endLineText="${4:-""}"; 
    local _contextSeparator="${5:-": "}";

    local currentPrefix="$_allLinesPrefix"
    local ret=""
    local errorPart

    while [ -n "$errorMessage" ]; do
        if [[ "$errorMessage" == *"$_contextSeparator"* ]]; then
            errorPart="${errorMessage%%$_contextSeparator*}"  # parte antes do separador
            errorMessage="${errorMessage#*$_contextSeparator}" # parte depois do separador
        else
            errorPart="$errorMessage"
            errorMessage=""
        fi

        if [ -n "$ret" ]; then
            ret+=$'\n'"$currentPrefix$_beginLineText$errorPart$_endLineText"
        else
            ret+="$currentPrefix$errorPart$_endLineText"
        fi

        currentPrefix+="  "
    done

    shu.printRed "$ret"$'\n' > /dev/stderr
}

shu.getShuProjectRoot_relative(){
    #look for a .shu folder in the current directory (director of script that called misc.Import). If not found, look in the parent, and so on
    local shuLocation="./"
    while [ ! -d "$shuLocation/.shu" ] && [ "$shuLocation" != "/" ]; do
        shuLocation+="../"
        local realpath="$(realpath "$shuLocation")"

        if [ "$realpath" == "/" ]; then
            shuLocation="/"
            break
        fi
    done

    if [ ! -d "$shuLocation/.shu" ]; then
        _error="Could not find .shu folder in the current directory or any parent directory"
        return 1
    fi

    _r="$shuLocation"
    return 0
}


#return _r with a text that can be printed to the console. The line length is 
#defined by tput cols, or 80 if tput is not available.
#_print ($2) can be used to control if the line should be printed or not. The
#default behavior is to print the line (_print = true).
shu.CreateHorizontalLine(){ local _char="${1:-"-"}"; local _print="${2:-true}"
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

#TODO: move files 
#Shu-cli direct commands (commands with no sub-cli) {
    #Initialize a new Shu project in the current directory by creating a shu.yaml file.
    shu.Init(){ local projectName=${1:-$(basename "$(pwd)")}
        if [ -f "./shu.yaml" ]; then
            _error="this directory is already a Shu project."
            return 1
        fi

        shu.initFolder "$projectName"
        shu.main touch "$projectName.sh"
        shu.main mainfiles add "$projectName.sh"

        #TODO: clone miscellaneous to ./shu/packages/shu-common
        #TODO: create main.sh file
        #TODO: add 'source ./shu/packages/shu-common/shu-shu.sh' to the main file

        echo "Initialized Shu project '$projectName'."
    }

    #deletes the .shu folder
    shu.Clean(){
        shu.main dep clean $@
    }

    #restore all dependencies from shu.yaml. If .shu folder already exists, the process is aborted
    shu.Restore(){
        #send arguments, bcause shu.Deprestore may need them
        shu.main dep restore $@

        #do not need to check Cmddeps, because shu.Deprestore already does it
    }

    #deletes .shu folder and restores it ('runs shu clean' and 'shu restore')
    shu.Refresh(){
        shu.main dep clean
        shu.main dep restore
    }

    shu.Tests(){
        shu.main test "$@"
        return  $?
    }

    shu.Help(){
        local output=""
        #just reduce the lines above
        helpItem(){ output+=$(shu.printHelpLine "$1"); }

        helpItem "Shu CLI version $SHU_VERSION - A package manager for shellscripting.\n"
        helpItem "Usage:\n"
        helpItem "  1) shu <command> [options]\n"
        helpItem "\n"
        helpItem "Commands:\n"
        helpItem "  init [projectName]       - Initialize a new Shu project in the current directory.\n"
        helpItem "  touch <scriptName>...    - Create a new .sh file with a basic structure.\n"
        helpItem "  get <urls>...            - Get one or more packages from Git URL and add it to the project. redirects to 'shu dep get <url>' (see int the 'dep' subcommand).\n"
        helpItem "  clean                    - Remove the .shu folder and all installed packages.\n"
        helpItem "  restore                  - Restore all dependencies from shu.yaml.\n"
        helpItem "  refresh                  - Clean and restore all dependencies from shu.yaml.\n"
        helpItem "  setmain <scriptName>     - Set a script as the main script for the project.\n"
        helpItem "  run [scriptName]         - Run the main script or a specific script.\n"
        helpItem "  install <url>            - Install a package from a URL to your system. Note that this command will install to be executed in your system, and not in your project. It is used to install projects written with SHU. Redirects to 'shu installer install'\n"
        helpItem "  uninstall <packageOrCommandName>\n"
        helpItem "                           - Uninstall a package or command from your sytem. Note that this command will not operate in your project, but in packages installed in your system via 'shu install'. Redirects to 'shu installer uninstall'\n"

        #list files in 'commands folder
        files="$(find "$(dirname "$shu_scriptFullPath")/commands" -type f -name "*.sh" )"
        for file in $files; do
            #helpItem "\n"
            while IFS= read -r line; do
                helpItem "  $line\n"
            done < <(source "$file" --help)
        done
        
        
        helpItem "\n\nAdditional information: Virtually, shu can install any git repository to you project.\n"

        printf "$output"

    }

    #uses tput to get the size of the terminal and prints a help line with the given text.
    #if line is to long, it will be split and idented.
    #Identation position is calculated by finding the last sequence of two spaces in the line.
    shu.printHelpLine(){ local line="$1"
        #find the '|-' sequence in the line
        #optional |- sequence (remove from final string)
        local sub="|-"
        local identPos=$(( $(expr match "$line" ".*${sub}") - ${#sub} ))
        if [ "$identPos" -gt 1 ]; then
            line="${line/$sub/}"
        else
            sub="- "
            identPos=$(( $(expr match "$line" ".*${sub}") - ${#sub} ))
        fi

        identPos=$((identPos + 2))
        local terminalWidth=$(tput cols)
        local identSpaces="$(printf "%${identPos}s" " ")"
        local maxSizeOfPrintedLines=$((terminalWidth - identPos))

        if [ "$terminalWidth" -le $identPos ]; then
            #if terminal width is less than identPos, just print the line
            echo "$line"
            return 0
        fi

        #remove the $sub from the line
        #line="${line/$sub/}"

        local sizeOfNextPrint=$terminalWidth;
        local printIdent=false;
        
        local result=""
        while true; do

            #check if line is empty
            if [ -z "$line" ]; then
                break
            fi

            
            while true; do
                #get character at position $sizeOfNextPrint
                local char="${line:$sizeOfNextPrint:1}"
                if [[ "$char" == "" || "$char" == " " ]]; then
                    #line was no spaces untils the $sizeOfNextPrint position
                    break
                fi
                sizeOfNextPrint=$((sizeOfNextPrint - 1))
            done
            local toPrint="${line:0:$sizeOfNextPrint}"
            line="${line:$sizeOfNextPrint}"

            if $printIdent; then
                printf "$identSpaces"
            fi

            echo "$toPrint"

            printIdent=true
            sizeOfNextPrint=$maxSizeOfPrintedLines
        done


    }

    _shu_autocomplete() {
        local cur prev
        COMPREPLY=()

        local cmds=""

        if [[ $COMP_CWORD -eq 1 ]]; then
            files="$(find "$SHU_PATH/commands" -type f -name "*.sh" )"
            for f in $files; do
                local cmdName=$(basename "$f" .sh)
                if [[ "$cmdName" != "shu-cli" && "$cmdName" != "shu-common" ]]; then
                    cmds+="$cmdName "
                fi
            done
            cmds="init get clean restore refresh setmain run install uninstall help $cmds"
            

            #list functions shu.* with capitalized name after shu.
        elif [[ $COMP_CWORD -eq 2 ]]; then
            local possibleFile="$SHU_PATH/commands/${COMP_WORDS[1]}.sh"
            if [ -f "$possibleFile" ]; then
                _r=""
                source "$possibleFile" "bashCompletion" "$@" 2>/dev/null
                if [ "$_r" != "" ]; then
                    cmds="${_r[@]}"
                fi
            fi
        fi

        COMPREPLY=( $(compgen -W "$cmds" -- "${COMP_WORDS[COMP_CWORD]}") )
            


        #cur="${COMP_WORDS[COMP_CWORD]}"
        #prev="${COMP_WORDS[COMP_CWORD-1]}"
#
        #local cmds="init build deploy help"
        #COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    }

    #clone $url to ~/.local/shu/installed
    #create a symlink for each script in the main section of shu.yaml to ~/.local/shu/bin
    #changes .bashrc to add ~/.local/shu/bin to PATH if not already present
    #add ~/.local/shu/bin to PATH if not already present
    shu.Install(){
        shu.main installer install "$@"
    }

    shu.Uninstall(){
        shu.main installer uninstall "$@"
        return $?
    }

    shu.Setmain(){ shu.main mainfiles "$@"; return $?; } #alias for shu.mainFileAdd

    shu.Run(){ shu.main mainfiles "$@"; return $?; } #alias for shu.mainFileRun

    shu.Get(){ shu.main dep get "$@"; return $?; } #alias for shu.main dep get


    #internal (private) functions {
        shu.initFolder(){
            #project name is in the first argument. If not present, use current directory name
            local projectName=${1:-$(basename "$(pwd)")}

            mkdir -p .shu

            if  [ ! -f "shu.yaml" ]; then
                cp "$(dirname "$shu_scriptFullPath")/assets/templates/shu.yaml" ./
                
                shu.yaml.set "shu.yaml" ".name" "$projectName"
                
                #check if .gitignore exists, if not, create it
                if [ ! -f ".gitignore" ]; then
                    echo "# Shu cache and packages" > .gitignore
                    echo ".shu/" >> .gitignore
                else
                    #check if .shu/ is already in .gitignore
                    if ! grep -q ".shu/" ".gitignore"; then
                        echo "# Shu cache and packages" >> .gitignore
                        echo ".shu/" >> .gitignore
                    fi
                fi

                shu.main dep get "$SHU_COMMON_FOLDER_SOURCE as shu-common" --not-recursive
            fi
        }

        
    #}
#}

#shu project commands {

    #Add a project command.
    #You can:
    #   shu Pcommand add <command> <packageName/cmdFile.sh> <information>
    #   shu Pcommand add <command1> <packageName/cmdFile1.sh> <information1> <command2> <packageName/cmdFile2.sh> <information2> ...
    #   shu Pcommand add <command1:packageName/cmdFile1.sh:information1> <command2:packageName/cmdFile2.sh:information2> ...
    shu.Pcommandadd(){
        shu.initFolder

        local command="$1";
        local packageAndFile="$2"
        local information="$3"

        if [[ "$command" =~ ^([^:=]+)[:=](.*)$ ]]; then
            command="${BASH_REMATCH[1]}"
            packageAndFile="${BASH_REMATCH[2]}"
            information="${BASH_REMATCH[3]}"
            shift 1
        else
            shift 3
        fi


        shu._pcmddepadd "$command" "$packageAndFile" "$information"
        if [ "$_error" != "" ]; then
            _error="Error adding project command '$command': $_error"
            return 1
        fi

        if _r="updated"; then
            echo "Project command '$command' updated."
        else
            echo "Project command '$command' added to project."
        fi

        #recursive call for remain arguments
        if [ "$#" -gt 0 ]; then
            shu.Pcommandadd "$@"
            if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
            return $?
        fi

        _r=""
        _error=""
        return 0    
    }

    shu.Pcommandremove(){ local command="$1"; shift
        if [ "$command" == "" ]; then
            _error="No project command name provided. Please provide a command name to remove from pcmds section."
            return 1
        fi

        shu.initFolder

        #check if command is in the pcmds section of shu.yaml
        shu.getPCmdDepIndex "$command"; local index="$_r"
        if [ "$index" == "-1" ]; then
            _error="Project command '$command' is not in the pcmds section of shu.yaml. Please provide a valid command name."
            return 1
        fi

        #remove command from the pcmds section
        shu.yaml.removeArrayElement "shu.yaml" ".project-commands" "$index"
        if [ "$_error" != "" ]; then
            _error="Error removing project command '$command' from pcmds section of shu.yaml: $_error"
            return 1
        fi

        shu.yaml.get "shu.yaml" ".name"; local projectName="$_r"
        echo "Project command '$command' removed from pcmds section of project '$projectName'."
        _error=""

        #recursive call for remain arguments
        if [ "$#" -ne 0 ]; then
            shu.Pcommandremove "$@"
            return $?
        fi
    }

    shu.Pcommandlist(){
        shu.initFolder

        #get all project commands from shu.yaml
        shu.yaml.getArray "shu.yaml" ".project-commands[]"; local pcmds=("${_r[@]}")
        if [ "$_error" != "" ]; then
            _error="Error getting project commands from shu.yaml: $_error"
            return 1
        fi

        if [ "${#pcmds[@]}" -eq 0 ]; then
            echo "No project commands found in the project."
            return 0
        fi

        echo "Project commands:"
        for pcmd in "${pcmds[@]}"; do
            local cmdName=$(echo "$pcmd" | cut -d ':' -f 2)
            local packageAndPath=$(echo "$pcmd" | cut -d ':' -f 3)
            local information=$(echo "$pcmd" | cut -d ':' -f 4-)

            echo "- $cmdName: $packageAndPath ($information)"
        done
    }

    shu.Pcommandexists(){ local command="$1"
        if [ "$command" == "" ]; then
            echo "erro 1"
            _error="No project command name provided. Please provide a command name to check."
            _r="false"
            return 1
        fi

        #check if command is in the pcmds section of shu.yaml
        shu.getPCmdDepIndex "$command"; local index="$_r"
        if [ "$index" == "-1" ]; then
            _r="false"
            return 1
        fi

        echo 33

        _r="true"
        _error=""
        return 0
    }

    #returns _r with 'updated' if command was updated, or empty string if command was added
    shu._pcmddepadd(){ local command="$1"; local packageAndPath="$2"; local information="$3"
        if [ "$command" == "" ]; then
            _error="No project command name provided. Please provide a command name to add to cmddeps section."
            return 1
        fi

        if [ "$packageAndPath" == "" ]; then
            _error="No package name or path provided for project command '$command'."
            return 1
        fi

        #check if command is already in the pcmds section of shu.yaml
        #pcmds is a object, where the key is the command name and the value is the information about the command
        shu.getPCmdDepIndex "$command"; local index="$_r"
        local forceUpdate=false
        if [ "$index" != "-1" ]; then
            #check if there is --force or -f in the arguments
            if [[ "$@" == *"--force"* ]] || [[ "$@" == *"-f"* ]]; then
                shu.yaml.removeArrayElement "shu.yaml" ".project-commands" "$index"
                if [ "$_error" != "" ]; then
                    _error="Error updating project command '$command': $_error"
                    return 1
                fi

                forceUpdate=true
            else
                _error="Project command '$command' is already set in your project. User --force to updates its information."
                return 1
            fi
        fi

        shu.yaml.appendObject "shu.yaml" ".project-commands" "cmd:$command" "path:$packageAndPath" "info:$information"
        if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
            _error="Error adding project command '$command': $_error"
            return 1
        fi

        error=""
        _r=""
        if [ "$forceUpdate" == "true" ]; then
            _r="updated"
        fi

        return 0
    }

    shu.getPCmdDepIndex(){ local command="$1"
        #get the index of the command in the cmddeps section of shu.yaml
        local index=0;
        while true; do
            shu.yaml.getArrayObject "shu.yaml" ".project-commands" "$index"; local pcmds=("${_r[@]}")
            if [ "$_error" == "$ERROR_INDEX_OUT_OF_BOUNDS" ]; then
                _error=""
                _r="-1"
                break;
            elif [ "$_error" != "" ]; then
                _error="Error getting project commands from shu.yaml: $_error"
                _r="-1"
                return 1
            fi
            
            if [ "${#pcmds[@]}" -eq 0 ]; then
                _error=""
                _r="-1"
                return 0
            fi

            if [ "${pcmds[0]}" == "cmd:$command" ]; then
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


#}

#functions for manipulating yaml files {
    #return 0 if the key exists in the yaml file, 1 otherwise. Also sets _r to 'true' or 'false'
    shu.yaml.containsKey(){ local file="$1"; local key="$2"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$key" == .* ]]; then
            #remove the first dot from the key
            key="${key:1}"
        fi

        #check if the key exists in the yaml file
        tmp=$(yq eval ".$key" "$file")
        if [ "$tmp" != "null" ]; then
            _r="true"
            _error=""
            return 0
        else
            _r="false"
            return 1
        fi
    }

    shu.yaml.listContains() {
        local file="$1"; local key="$2"; local value="$3"

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        # check if the key exists in the yaml file
        if ! shu.yaml.containsKey "$file" "$key"; then
            _error="Key '$key' not found in file '$file'."
            return 1
        fi

        # check if the value exists in the list
        if yq eval ".\"$key\"[]" "$file" | grep -Fxq "$value"; then
            _r="true"
            return 0
        else
            _r="false"
            return 1
        fi
    }

    #return an array with key[: value]
    shu.yaml.listProperties(){ local file="$1"; local key="$2"; local _allwValues="${3:-false}"
        ret=()
        shu.yaml.getArray "shu.yaml" "$key | keys | .[]"; local tmpResult=("${_r[@]}")
        if [ "$_error" != "" ]; then
            _error="Error getting properties from yaml file '$file': $_error"
            return 1
        fi

        for prop in "${tmpResult[@]}"; do
            if [ "$_allwValues" == "true" ]; then
                shu.yaml.get "shu.yaml" "$key.$prop"; local value="$_r"
                ret+=("$prop: $value")
            else
                ret+=("$prop")
                
            fi
        done

        _r=("${ret[@]}")
    }

    #returns, via _r, the value of the key in the yaml file (note that the value can be a list)
    shu.yaml.get() {
        local file="$1"
        local key="$2"

        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's version in Go)."
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$key" == .* ]]; then
            key="${key:1}"
        fi

        _r=$(yq eval ".${key}" "$file")
        _error=""
        return 0
    }

    shu.yaml.getArray() {
        local file="$1"
        local key="$2"

        #add the [] to the key if it does not have it
        if [[ "$key" != *"[]" ]]; then
            key="$key[]"
        fi

        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's version in Go)."
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$key" == .* ]]; then
            key="${key:1}"
        fi

        _r=()

        while IFS= read -r line; do
            _r+=("$line")
        done < <(yq eval ".${key}" "$file")

        _error=""
        return 0
    }

    #returns _r with a bash array of string in the format "key:value"
    shu.yaml.getArrayObject(){ local file="$1"; local key="$2"; local index="$3"
        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's version in Go)."
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$key" == .* ]]; then
            key="${key:1}"
        fi

        # Verifica se o índice é número
        if ! [[ "$index" =~ ^[0-9]+$ ]]; then
            _error="Index must be a non-negative integer."
            return 1
        fi

        # Verifica se o índice é válido
        local arrayLength
        arrayLength=$(yq eval ".${key} | length" "$file")
        if [ "$index" -lt 0 ] || [ "$index" -ge "$arrayLength" ]; then
            _error="$ERROR_INDEX_OUT_OF_BOUNDS"
            return 1
        fi

        # Extrai as keys do objeto no índice
        local keys
        mapfile -t keys < <(yq eval ".${key}[$index] | keys[]" "$file")

        # Para cada key, extrai o valor e monta key:value
        _r=()
        for k in "${keys[@]}"; do
            # Remove aspas se houver no k
            k="${k%\"}"
            k="${k#\"}"

            local value
            value=$(yq eval ".${key}[$index].$k" "$file")
            # Remove aspas do value, se existir
            value="${value%\"}"
            value="${value#\"}"

            _r+=("$k:$value")
        done

        _error=""
        return 0
        

    }

    shu.yaml.removeArrayElement() {
        local file="$1"
        local arrayKey="$2"
        local index="$3"

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's version in Go)."
            return 1
        fi


        if [[ "$arrayKey" == .* ]]; then
            #remove the first dot from the key
            arrayKey="${arrayKey:1}"
        fi

        yq eval -i ".${arrayKey} |= del(.[${index}])" "$file" 2>/tmp/shu-yaml-remove-array-element-error.log
        if [ $? -ne 0 ]; then
            _error="Error removing element at index '$index' from array '$arrayKey' in file '$file': $(cat /tmp/shu-yaml-remove-array-element-error.log)"
            rm /tmp/shu-yaml-remove-array-element-error.log
            return 1
        fi
        rm /tmp/shu-yaml-remove-array-element-error.log
        _error=""
        return 0
    }

    shu.yaml.appendObject() {
        local file="$1"
        local arrayKey="$2"
        shift 2

        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's version in Go)."
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$arrayKey" == .* ]]; then
            arrayKey="${arrayKey:1}"
        fi

        # Monta o objeto JSON
        local json_obj="{"
        local first=1
        for kv in "$@"; do
            local key="${kv%%:*}"
            local value="${kv#*:}"
            # Adiciona vírgula para todos menos o primeiro
            if [ $first -eq 0 ]; then
                json_obj+=","
            fi
            # Escapa aspas simples no valor e monta par chave: valor string
            value=${value//\'/\'\\\'\'}
            json_obj+="\"$key\":\"$value\""
            first=0
        done
        json_obj+="}"

        # Garante que a chave é uma lista (cria se não existir)
        yq eval "if .${arrayKey} == null or .${arrayKey} | type != \"!!seq\" then .${arrayKey} = [] else . end" -i "$file"

        # Adiciona o objeto ao array
        yq eval ".${arrayKey} += [${json_obj}]" -i "$file"
    }

    #erase the value of the key in the yaml file and set it to the value provided
    shu.yaml.set() {
        local file="$1"
        local key="$2"
        local value="$3"

        if [[ "$key" == .* ]]; then
            #remove the first dot from the key
            key="${key:1}"
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        #check if yq is installed
        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's) to use this function."

            return 1
        fi

        yq eval -i ".$key = \"$value\"" "$file" 2>/tmp/shu-yaml-set-error.log
        if [ $? -ne 0 ]; then
            _error="Error setting key '$key' to value '$value' in file '$file': $(cat /tmp/shu-yaml-set-error.log)"
            rm /tmp/shu-yaml-set-error.log
            return 1
        fi
        rm /tmp/shu-yaml-set-error.log

        _error=""
    }

    #append a value to the key in the yaml file. If the key does not exist, it will be created.
    shu.yaml.append(){ local file="$1"; local key="$2"; local value="$3"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        #check if the key exists in the yaml file
        if shu.yaml.containsKey "$file" "$key"; then
            #append the value to the key
            yq eval -i "$key += [\"$value\"]" "$file"
        else
            #create the key and set the value
            yq eval -i "$key= [\"$value\"]" "$file"
        fi

        if [[ "$key" == .* ]]; then
            #remove the first dot from the key
            key="${key:1}"
        fi

        if [ $? -ne 0 ]; then
            _error="Error appending value '$value' to key '$key' in file '$file'."
            return 1
        fi

        _error=""
    }

    shu.yaml.remove(){ local file="$1"; local key="$2"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        #check if the key exists in the yaml file
        if shu.yaml.containsKey "$file" "$key"; then
            yq eval -i "del(.${key})" "$file"
            if [ $? -ne 0 ]; then
                _error="Error removing key '$key' from file '$file'."
                return 1
            fi
        else
            _error="Key '$key' not found in file '$file'."
            return 1
        fi

        _error=""
    }
#}


# Se o script estiver sendo *sourced*, registre o autocompletion
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    complete -F _shu_autocomplete shu
    export SHU_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    return

fi


shu.main "$@"; retCode=$?
exit $retCode
