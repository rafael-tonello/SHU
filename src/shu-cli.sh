#!/bin/bash

SHU_VERSION="0.1.0"
shu_scriptFullPath="$(realpath "$0")"
shu_scriptDir="$(dirname "$shu_scriptFullPath")"
export SHU_PROJECT_WORK_DIR="" #setted by shu.Main
export SHU_PROJECT_ROOT_DIR="" #setted by shu.Main. if empty, it means that the current directory is not a shu project
export SHU_PROJECT_NAME="" #setted by shu.Main. if empty, it means that the current directory is not a shu project
export SHU_BINARY="$0"

#Common errors
    ERROR_AREADY_DONE="already done"
    ERROR_NO_SHU_DIRECTORY="is not shu project/directory. No shu.yaml found"
    ERROR_INDEX_OUT_OF_BOUNDS="index out of bounds"
    ERROR_NO_HOOKS_FOUND="No hooks found"
    ERROR_COMMAND_REQUIRES_SHU_PROJECT="this commands only works inside a shu project"
    ERROR_YQ_NOT_INSTALLED="yq is not installed. Please install yq (Mike Farah's, https://github.com/mikefarah/yq) to use this function (from Yq repo:wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq)."
#}

#shu values that can be overridden by environment variables {
    if [ -z "$SHU_GIT_REPO" ]; then SHU_GIT_REPO="https://github.com/rafael-tonello/SHU.git"; fi
    if [ -z "$SHU_COMMON_FOLDER_SOURCE" ]; then SHU_COMMON_FOLDER_SOURCE="$SHU_GIT_REPO#src/shellscript-fw/common"; fi
#}

shu.detectEnvAndGoRoot(){
    export SHU_PROJECT_WORK_DIR="$(pwd)"
    shu.getShuProjectRootDir; local retCode=$?; export SHU_PROJECT_ROOT_DIR="$_r"
    if [ $retCode -eq 0 ]; then
        cd "$SHU_PROJECT_ROOT_DIR"
        shu.yaml.get "shu.yaml" ".name"; export SHU_PROJECT_NAME="$_r"
    else
        export SHU_PROJECT_ROOT_DIR=""
    fi
}

shu.Main(){ local cmd="$1";
    shu.detectEnvAndGoRoot
    local currDir="$SHU_PROJECT_ROOT_DIR" #if a command file calls main, the SHU_PROJECT_* variables could be changed. So, we need to restore the pwd and these variables after run command file

    if [[ "$cmd" == "-h" || "$cmd" == "--help"  || $# -eq 0 ]]; then
        shu.Help "$@"
        return 0
    elif [[ "$cmd" == "-v" || "$cmd" == "--version" ]]; then
        echo "Shu CLI version $SHU_VERSION"
        return 0
    fi
    shift;
    
    shu.checkPrerequisites
    if [ $? -ne 0 ]; then
        shu.printError "Some dependencies are missing and shu cannot continue: $_error"; _error=""
        cd "$SHU_PROJECT_WORK_DIR"
        return 1
    fi

    local capitalizedCmd=$(echo "$cmd" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    _error=""

    #check and run hooks
    #check if hooks.sh file is available 
    cd "$SHU_PROJECT_ROOT_DIR"
    if [ "$SHU_PROJECT_ROOT_DIR" != "" ]; then
        local shuHooksFile="$shu_scriptDir/commands/hooks.sh"
        if [ -f "$shuHooksFile" ]; then

            source "$shuHooksFile" "run" "before" "$cmd" "$@"; local retCode=$?; local err="$_error"

            #if file changes the current directory, and change SHU_PROJECT* variables (by calling shu.Main), restore them
            cd "$currDir"
            shu.detectEnvAndGoRoot
            _error="$err" #detectEnvAndGoRoot clears variable _error

            if [[ -n "$_error" && $_error != *"$ERROR_NO_HOOKS_FOUND"* ]]; then
                shu.printError "Shu error running hooks before command: $_error"; _error=""
                cd "$SHU_PROJECT_WORK_DIR"
                return $retCode
            fi
        else
            shu.printYellow "Warning: shu hooks module is missing. File '$shu_scriptDir/commands/hooks.sh' not found. Hooks will not be executed.\n" >/dev/stderr
        fi
    fi
    _error=""
    #check if project contains the command
    cd "$SHU_PROJECT_ROOT_DIR"
    
    shu.yaml.containsKey "shu.yaml" ".project-commands.$cmd"; local exists="$_r"
    if [ "$exists" == "true" ]; then
        #run the command from the project
        if [ ! -f "$shu_scriptDir/commands/pcommands.sh" ]; then
            shu.printError "Shu error:  Error running project command \"$cmd\": pcommands.sh not found in the commands folder."; _error=""
        fi

        source "$shu_scriptDir/commands/pcommands.sh" "run" "$cmd" "$@"; local retCode=$?
        cd "$SHU_PROJECT_WORK_DIR"
        if [ "$retCode" -ne 0 ]; then
            shu.printError "Shu error: Error running project command \"$cmd\": $_error"; _error=""
            return 1
        fi
        return $retCode
    fi
    _error=""

    local retCode=0

    #check if lowercase of capitalizedCmd contains 'Run' or 'run' (do not supress stderr when running scripts using shu)
    if [[ "$capitalizedCmd" == *"Run"* ]]; then
        shu.Run "$@"
        retCode=$?
    elif type "shu.$capitalizedCmd" &> /dev/null; then
        shu.$capitalizedCmd "$@"
        retCode=$?

        if [ "$_error" != "" ]; then
            shu.printError "Shu error: $_error"; _error=""
        fi
        return $retCode
    else
        #check if the folder $shu_scriptFullPath/.shu/packages/common/commands/$cmd.sh exists 
        local commandFile="$shu_scriptDir/commands/$cmd.sh"
        if [ -f "$commandFile" ]; then
            #run the command file
            source "$commandFile"
            retCode=$?
            if [ "$retCode" -ne 0 ] || [ "$_error" != "" ]; then
                
                shu.printError "Shu error: Error running command '$cmd': $_error";
                _error=""
                rm -f /tmp/shu_error.log
                return 1
            fi
            rm -f /tmp/shu_error.log
            cd "$SHU_PROJECT_WORK_DIR"
        else
            shu.printError "Command '$cmd' not found in your project, nor in the SHU commands. User 'shu pcommand --help' to see the available project commands, or 'shu --help' to see the available SHU commands."; _error=""
            retCode=1
        fi
    fi

    #if file changes the current directory, and change SHU_PROJECT* variables (by calling shu.Main), restore them
    cd "$currDir"
    shu.detectEnvAndGoRoot

    cd "$SHU_PROJECT_ROOT_DIR"
    if [ "$SHU_PROJECT_ROOT_DIR" != "" ]; then

        #check if hooks.sh file is available 
        local shuHooksFile="$shu_scriptDir/commands/hooks.sh"
        if [ -f "$shuHooksFile" ]; then
            source "$shuHooksFile" "run" "after" "$cmd" "$@"; local retCode=$?; local err="$_error"
            #if file changes the current directory, and change SHU_PROJECT* variables (by calling shu.Main), restore them
            cd "$currDir"
            shu.detectEnvAndGoRoot
            _error="$err"  #detectEnvAndGoRoot clears variable _error

            if [[ -n "$_error" && $_error != *"$ERROR_NO_HOOKS_FOUND"* ]]; then
                shu.printError "Shu error running hooks after commnad: $_error"; _error=""
                cd "$SHU_PROJECT_WORK_DIR"
                return $retCode
            fi
        else
            shu.printYellow "Warning: shu hooks module is missing. File '$shu_scriptDir/commands/hooks.sh' not found. Hooks will not be executed.\n" >&2
        fi
    fi
    _error=""
    
    cd "$SHU_PROJECT_WORK_DIR"
    return 0
}

#utils functions {
    shu.checkPrerequisites(){
        local retCode=0
        _error=""

        #check if yq is installed
        if ! command -v yq &> /dev/null; then
            if [ "$_error" != "" ]; then _error+="+ "; fi
            _error+="yq is not installed. Please install yq to use Shu (go install github.com/mikefarah/yq/v4@latest). Read more in https://github.com/mikefarah/yq"
            retoCode=1
        fi

        #check git
        if ! command -v git &> /dev/null; then
            if [ "$_error" != "" ]; then _error+="+ "; fi
            _error+="git is not installed. Shu needs git to install project dependencies."
            retCode=1
        fi

        if ! command -v split &> /dev/null; then
            if [ "$_error" != "" ]; then _error+="+ "; fi
            _error+="split is not installed. Shu uses shu."
            retCode=1
        fi

        if ! command -v curl &> /dev/null; then
            if [ "$_error" != "" ]; then _error+="+ "; fi
            _error+="Curl is not installed. Please install Curl to use Shu."
            retCode=1
        fi

        ##check if jq is installed
        #if ! command -v jq &> /dev/null; then
        #    _error="jq is not installed. Please install jq to use Shu."
        #    return 1
        #fi

        return $retCode
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

    shu.printYellow(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;33m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    #prints contextual erros.
    #erros are nested by ':'
    #print each erro in a single line
    #use identation to show nesting
    shu.printError(){
        local error="$1"
        local _currIdentation="$2"
        local _currPrefix_="${3:-}"

        
        local currError=""

        if [[ "$error" == *": "* ]]; then
            currError="${error%%: *}"
            error="${error#*: }"
        else
            currError="$error"
            error=""
        fi
        shu.printError.printSameLevelError "$currError" "$_currIdentation  " "$_currPrefix_"
        if [[ -n "$error" ]]; then
            #change prefix of next errors to ': '
            shu.printError "$error" "$_currIdentation  " "⤷ "
        fi
    }

    #same level erros are erros separated by '+' and should be printed in induaviadual lines, but with the same identation
    shu.printError.printSameLevelError(){
        local error="$1"
        local currIdentation="$2"
        local _prefix_="$3"

        local currError=""
        if [[ "$error" == *" + "* ]]; then
            currError="${error%%" + "*}"
            error="${error#*" + "}"
        else
            currError="$error"
            error=""
        fi

        #print to stderr
        shu.printRed "$currIdentation$_prefix_$currError\n" >&2
        if [[ -n "$error" ]]; then
            #change prefix of next errors to '+ '
            shu.printError.printSameLevelError "$error" "$currIdentation" "+ "
        fi
    }

    shu.getShuProjectRootDir(){
        #look for a .shu folder in the current directory (director of script that called misc.Import). If not found, look in the parent, and so on
        local shuLocation="$(pwd)"
        while [ ! -f "$shuLocation/shu.yaml" ] && [ "$shuLocation" != "/" ]; do
            shuLocation="$(dirname "$shuLocation")"
        done

        if [ ! -f "$shuLocation/shu.yaml" ]; then
            _error="Could not find .shu folder in the current directory or any parent directory"
            _r=""
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

    #separate a key value. Try to separate key value by ':', by '=' or from "$1 $2"
    shu.separateKv(){
        #check if $1 contains '=' or ':'
        local key=$1
        local value="$2"
        if [[ "$1" == *"="* ]]; then
            local key="${1%%=*}"
            local value="${1#*=}"
        elif [[ "$1" == *":"* ]]; then
            local key="${1%%:*}"
            local value="${1#*:}"
        fi

        _r=("$key" "$value")
        _r_key="$key"
        _r_value="$value"
        return 0
    }

    shu.getValueFromArgs(){ local key="$1"; shift
        #check if key is in the arguments list
        _r=""
        _error=""
        local index=0
        local i=0;
        local arg=""
        local nextArg=""
        local totalArgs=$#
        for (( i=0; i<$#; i++ )); do
            arg="${!i}"
            if [ $i -lt $(( $totalArgs - 1 )) ]; then
                local nextArgPos=$((i+1))

                nextArg="${!nextArgPos}"
            fi

            if [[ "$arg" == "$key"* ]]; then
                shu.separateKv "$arg" "$nextArg"; _r="$_r_value"
                return 0
            fi
        done

        _r=""
        _error="Key '$key' not found in the arguments list"
        return 1
    }

    #locate an argument by its name (--arg, -a)
    #names should be a space separated list of names, e.g. "--arg1 --arg2 -a3"
    #arg and value can be separated by a space, an equal sign (=) or a colon (:)
    shu.getValueFromArgs_manyNames(){ local possibleNames="$1"; local defaultValue="$2"; shift 2
        for possibleName in $possibleNames; do
            shu.getValueFromArgs "$possibleName" "$@"
            if [ "$?" -eq 0 ]; then
                _error=""
                return 0
            fi
        done
        _r="$defaultValue"
        _error="Argument '$possibleName' not found in the arguments."
        return 1
    }
#}

#TODO: move files 
#Shu-cli direct commands (commands with no sub-cli) {
    #Initialize a new Shu project in the current directory by creating a shu.yaml file.
    shu.Init(){ local projectName=${1:-$(basename "$(pwd)")}
        if [ -f "./shu.yaml" ]; then
            shu.printYellow "Warning: This project is already initialized. Redirecting to 'shu restore'.\n"
            shu.Main restore
            return $?
        fi

        shu.initFolder "$projectName"

        #check for --template option
        shu.getValueFromArgs "--template"
        if [ "$?" -eq 0 ]; then
            _error=""
            local template="$_r"
            local tmpFolder="$(mktemp -d)"

            #check if is a valid git repo
            local retDir="$(pwd)"
            cd tempFolder
            shu.Main init

            #check if template contains 'as <name>'
            if [[ "$template" =~ as\ ([^ ]+) ]]; then
                _error="You cannot use 'as <name>' in the template option."
                return 1
            fi

            shu.Main pdeps get "$template as shu-template"
            if [ "$_error" != "" ]; then
                _error="Error getting template '$template': $_error"
                return 1
            fi

            cp -r "$tmpFolder/.shu/packages/shu-template/"* ./

            rm -rf "$tmpFolder"

            #updates project name
            shu.yaml.set "shu.yaml" ".name" "$projectName"
        else
            _error=""
            shu.Main touch "$projectName.sh"
            shu.Main mainfiles add "$projectName.sh"
        fi

        echo "Initialized Shu project '$projectName'."
        echo "Use 'shu restore' to restore the dependencies of the project."
    }

    #deletes the .shu folder
    shu.Clean(){
        shu.Main pdeps clean $@
    }

    #restore all dependencies from shu.yaml. If .shu folder already exists, the process is aborted
    shu.Restore(){
        #send arguments, bcause shu.Deprestore may need them
        shu.Main pdeps restore $@

        echo "Use shu --help to get more information and see the available commands."

        #do not need to check sysdepss, because shu.Deprestore already does it
    }

    #deletes .shu folder and restores it ('runs shu clean' and 'shu restore')
    shu.Refresh(){
        shu.Main pdeps clean
        shu.Main pdeps restore
    }

    shu.Help(){
        local onlyProject=false
        if [[ "$@" == *"--project-only"* || "$@" == *"-p"* ]]; then
            onlyProject=true

            if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
                shu.printError "help with -p/--project-only (show only project commands help) is only available inside a shu project folder."
                return 1
            fi
        fi

        local output=""
        pCommands=()
        source "$shu_scriptDir/commands/pcommands.sh" "list" '__f(){ local command="$1"; local commandAction="$2"; local description="$3"
            local commandStrSize=${#command}
            #if commandStrSize is less than 27
            if [ $commandStrSize -lt 27 ]; then
                local spaceCount=$((25 - commandStrSize))
                pCommands+=("$command$(printf '%*s' $spaceCount '') - $description")
            else
                local spaceCount=27
                pCommands+=("$command")
                pCommands+=("$(printf '%*s' $spaceCount '') - $description")
            fi
        }; __f'

        #just reduce the lines above
        helpItem(){ output+=$(shu.printHelpLine "$1"); }

        helpItem "Shu CLI version $SHU_VERSION - A package manager and project automation system."
        if $onlyProject; then
            helpItem " Printing only project commands help.\n"
        else
            helpItem "\n"
        fi

        helpItem "$(shu.printGreen Usage):\n"
        #check if pCommands is empty
        if [ ${#pCommands[@]} -eq 0 ]; then
            if $onlyProject; then
                shu.printError "You are trying to se only project commands help, but project '$SHU_PROJECT_NAME' does not have commands."
                return
            else
                helpItem "  shu <command> [options]\n"
            fi
        else
            if $onlyProject; then
                helpItem "  shu <project command> [options]\n"
            else
                helpItem "  shu <command|project command> [options]\n"
            fi
        fi

        if ! $onlyProject; then
            helpItem "\n"
            helpItem "$(shu.printGreen "Shu commands"):\n"
            helpItem "  init [projectName] [options]\n"
            helpItem "                           - Initialize a new Shu project in the current directory.\n"
            helpItem "    options:\n"
            helpItem "      --template \"<url[@<checkout_to>][#<path>][--allow-no-git]>\" [options]\n"
            helpItem "                             - Use a previus shu project as a template to initialize the current folder. The template can be a git repository, a file URL (zip, 7z, tar.gz, tar.bz2) or a directory. Internaly, this will use 'shu pdeps get' command to get the template.'\n"
            helpItem "      options:\n"
            helpItem "        --not-recursive        - Do not restore dependencies of the package.\n"
            helpItem "      @<checkout_to>         - Shu will checkout the repository to <checkout_to>.\n"
            helpItem "      #<path>                - Shu will copy only the contents of the specified path (in the repository) to the package folder.\n"
            helpItem "      --allow-no-git         - allow a no git repository. Shu will try to find it in the filesystem or download it from the web. If a download could be done, the shu will try to extract it if has a supported extension (.zip, .tar.gz, .tar.bz2, .7z).\n"
            helpItem "  touch <scriptName>...    - Create a new .sh file with a basic structure.\n"
            helpItem "  get <urls>...            - Get one or more packages from Git URL and add it to the project. redirects to 'shu pdeps get <url>' (see int the 'pdeps' subcommand).\n"
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
        fi

        if [ ${#pCommands[@]} -gt 0 ]; then
            helpItem "\n"

            local projectNameBold=$(printf "\033[1m%s\033[0m" "$SHU_PROJECT_NAME")

            helpItem "$(shu.printGreen "Project $projectNameBold ")$(shu.printGreen "Commands (commands registered in current shu.yaml file)"):\n"
            for pCommand in "${pCommands[@]}"; do
                helpItem "  $pCommand\n"
            done
        fi

        if ! $onlyProject; then
            helpItem "\n\n$(shu.printGreen "Additional information about Shu"):\n" 
            helpItem "  - Shu initially was focused on shellscripting, but it was changed over the time and, now, shu can work with (almost) any kind of software project, managing packages from git repositories and automating the project with commands, hooks and more.\n"
            helpItem "  - If you are hooking a command or writing commands for you project, shu exports some variables:\n"
            helpItem "    - SHU_PROJECT_ROOT_DIR: The root directory of the project. It is the directory where the shu.yaml file is located.\n"
            helpItem "    - SHU_PROJECT_WORK_DIR: The current working directory of the project\n"
            helpItem "    - SHU_LAST_DEP_GET_FOLDER: The folder where the last dependency was downloaded. It is only available after the 'shu pdeps get' be execute and is designed to be used in hooks.\n"
            helpItem "    - SHU_HOOK_INDEX: When running hooks, contains the index of the hook (in the 'shu.xml' hooks list).\n"
            helpItem "    - SHU_HOOK_WHEN: When running hooks, contains the moment when the hook is being executed (related to the command being executed). Possible values are 'before' and 'after'.\n"
            helpItem "    - SHU_HOOK_COMMAND_TO_RUN: When running hooks, contains the hooks commnad (your code).\n"
            helpItem "    - SHU_HOOK_COMMAND_TO_CHECK: When running hooks, contains the shu command that should be evaluated.\n"
            helpItem "    - SHU_HOOK_RECEIVED_COMMAND: When running hooks, contains the command that is being executed (the command that shu is running).\n"
            helpItem "    - SHU_BINARY: The path to the shu binary that is being executed. Useful when using shu embedded in a project.\n"
        fi

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
        if command -v tput &> /dev/null; then
            #use tput to get the terminal width
            local terminalWidth=$(tput cols)
        else
            #if tput is not available, use a default value
            local terminalWidth=100
        fi
        
        if [ "$terminalWidth" == "" ] || [ "$terminalWidth" -le 0 ]; then
            terminalWidth=100
        fi

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
                if [[ "$cmdName" != "shu-cli" && "$cmdName" != "common" ]]; then
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
        shu.Main installer install "$@"
    }

    shu.Uninstall(){
        shu.Main installer uninstall "$@"
        return $?
    }

    shu.Setmain(){ shu.Main mainfiles "$@"; return $?; } #alias for shu.MainFileAdd

    shu.Run(){ shu.Main mainfiles "$@"; return $?; } #alias for shu.MainFileRun

    shu.Get(){ shu.Main pdeps get "$@"; return $?; } #alias for shu.Main pdeps get


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

                shu.Main pdeps get "$SHU_COMMON_FOLDER_SOURCE as common --not-recursive"
            fi
        }

        
    #}
#}

#functions for manipulating yaml files {
    #return 0 if the key exists in the yaml file, 1 otherwise. Also sets _r to 'true' or 'false'

    #Set a key: value in the yaml file
    shu.yaml.set() {
        local file="$1"
        local pkey="$2"
        local value="$3"

        if [[ "$pkey" == .* ]]; then
            #remove the first dot from the pkey
            pkey="${pkey:1}"
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        #check if yq is installed
        if ! command -v yq &> /dev/null; then
            _error="$ERROR_YQ_NOT_INSTALLED"
            return 1
        fi

        yq eval -i ".$pkey = \"$value\"" "$file" 2>/tmp/shu-yaml-set-error.log
        if [ $? -ne 0 ]; then
            _error="Error setting key '$pkey' to value '$value' in file '$file': $(cat /tmp/shu-yaml-set-error.log)"
            rm /tmp/shu-yaml-set-error.log
            return 1
        fi
        rm /tmp/shu-yaml-set-error.log

        _error=""
    }

    #returns, via _r, the value of the key in the yaml file (note that the value can be a list)
    shu.yaml.get() {
        local file="$1"
        local pkey="$2"

        if ! command -v yq &> /dev/null; then
            _error="$ERROR_YQ_NOT_INSTALLED"
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            pkey="${pkey:1}"
        fi

        _r=$(yq eval ".${pkey}" "$file")
        _error=""
        return 0
    }

    shu.yaml.remove(){ local file="$1"; local pkey="$2"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            pkey="${pkey:1}"
        fi

        #check if the key exists in the yaml file
        if shu.yaml.containsKey "$file" "$pkey"; then
            yq eval -i "del(.${pkey})" "$file"
            if [ $? -ne 0 ]; then
                _error="Error removing key '$pkey' from file '$file'."
                return 1
            fi
        else
            _error="Key '$pkey' not found in file '$file'."
            return 1
        fi

        _error=""
    }

    #returns _r = true and ret code 0 if the key exists in the yaml file, _r = false and ret code 1 otherwise
    shu.yaml.containsKey(){ local file="$1"; local pkey="$2"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            #remove the first dot from the pkey
            pkey="${pkey:1}"
        fi

        #check if the pkey exists in the yaml file
        tmp=$(yq eval ".$pkey" "$file")
        if [ "$tmp" != "null" ]; then
            _r="true"
            _error=""
            return 0
        else
            _r="false"
            return 1
        fi
    }

    #return, via _r, a list of 'key: value' pairs from the yaml file.
    shu.yaml.listProperties(){ local file="$1"; local pkey="$2"; local _allwValues="${3:-false}"
        ret=()
        shu.yaml.getArray "shu.yaml" "$pkey | keys | .[]"; local tmpResult=("${_r[@]}")
        if [ "$_error" != "" ]; then
            _error="Error getting properties from yaml file '$file': $_error"
            return 1
        fi

        for prop in "${tmpResult[@]}"; do
            if [ "$_allwValues" == "true" ]; then
                shu.yaml.get "shu.yaml" "$pkey.$prop"; local value="$_r"
                ret+=("$prop: $value")
            else
                ret+=("$prop")
                
            fi
        done

        _r=("${ret[@]}")
    }

    #append a value to an array in the yaml file. If the key does not exist, it will be created.
    shu.yaml.addArrayElement(){ local file="$1"; local pkey="$2"; local value="$3"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            #remove the first dot from the pkey
            pkey="${pkey:1}"
        fi

        #check if the key exists in the yaml file
        if shu.yaml.containsKey "$file" ".$pkey"; then
            #append the value to the pkey
            yq eval -i ".$pkey += [\"$value\"]" "$file"
        else
            #create the pkey and set the value
            yq eval -i ".$pkey= [\"$value\"]" "$file"
        fi

        if [ $? -ne 0 ]; then
            _error="Error appending value '$value' to key '$pkey' in file '$file'."
            return 1
        fi

        _error=""
    }

    shu.yaml.arrayContains() {
        local file="$1"; local pkey="$2"; local value="$3"

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        # check if the pkey exists in the yaml file
        if ! shu.yaml.containsKey "$file" "$pkey"; then
            _error="Key '$pkey' not found in file '$file'."
            return 1
        fi

        # check if the value exists in the list
        if yq eval ".\"$pkey\"[]" "$file" | grep -Fxq "$value"; then
            _r="true"
            return 0
        else
            _r="false"
            return 1
        fi
    }

    shu.yaml.getArrayElement(){ local file="$1"; local pkey="$2"; local index="$3"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            #remove the first dot from the pkey
            pkey="${pkey:1}"
        fi

        # Verifica se o índice é número
        if ! [[ "$index" =~ ^[0-9]+$ ]]; then
            _error="Index must be a non-negative integer."
            return 1
        fi

        # Verifica se o índice é válido
        local arrayLength
        arrayLength=$(yq eval ".${pkey} | length" "$file")
        if [ "$index" -lt 0 ] || [ "$index" -ge "$arrayLength" ]; then
            _error="$ERROR_INDEX_OUT_OF_BOUNDS"
            return 1
        fi

        #check if the key exists in the yaml file
        if shu.yaml.containsKey "$file" ".$pkey"; then
            #get the value of the pkey at the index
            _r=$(yq eval ".${pkey}[${index}]" "$file")
            if [ $? -ne 0 ]; then
                _error="Error getting value of key '$pkey' at index '$index' in file '$file'."
                return 1
            fi
        else
            _error="Key '$pkey' not found in file '$file'."
            return 1
        fi

        _error=""
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
            _error="$ERROR_YQ_NOT_INSTALLED"
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

    #returns _r with a list of values of an array in the yaml file.
    shu.yaml.getArray() {
        local file="$1"
        local pkey="$2"

        #add the [] to the pkey if it does not have it
        if [[ "$pkey" != *"[]" ]]; then
            pkey="$pkey[]"
        fi

        if ! command -v yq &> /dev/null; then
            _error="$ERROR_YQ_NOT_INSTALLED"
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            pkey="${pkey:1}"
        fi

        _r=()


        while IFS= read -r line; do
            _r+=("$line")
        done < <(yq eval ".${pkey}" "$file" 2>/dev/null)

        _error=""
        return 0
    }
    
#}

    #append an object to an array in the yaml file. If the key does not exist, it will be created.
    #appendObjectToArray <file> <arrayKey> <key1:value1> <key2:value2> ...
    shu.yaml.appendObjectToArray() {
        local file="$1"
        local arrayKey="$2"
        shift 2

        if ! command -v yq &> /dev/null; then
            _error="$ERROR_YQ_NOT_INSTALLED"
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
            local pkey="${kv%%:*}"
            local value="${kv#*:}"
            # Adiciona vírgula para todos menos o primeiro
            if [ $first -eq 0 ]; then
                json_obj+=","
            fi
            # Escapa aspas duplas no valor e monta par chave: valor string
            value="${value//\"/\\\"}"  # Escapa aspas duplas
            json_obj+="\"$pkey\":\"$value\""
            first=0
        done
        json_obj+="}"

        # Garante que a chave é uma lista (cria se não existir)
        #yq eval "if .${arrayKey} == null or .${arrayKey} | type != \"!!seq\" then .${arrayKey} = [] else . end" -i "$file"

        # Adiciona o objeto ao array
        yq eval ".${arrayKey} += [${json_obj}]" -i "$file"
    }


    #returns _r with a associative array of pkeys and values
    shu.yaml.getObjectFromArray(){ local file="$1"; local pkey="$2"; local index="$3"
        if ! command -v yq &> /dev/null; then
            _error="$ERROR_YQ_NOT_INSTALLED"
            return 1
        fi

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        if [[ "$pkey" == .* ]]; then
            pkey="${pkey:1}"
        fi

        # Verifica se o índice é número
        if ! [[ "$index" =~ ^[0-9]+$ ]]; then
            _error="Index must be a non-negative integer."
            return 1
        fi

        # Verifica se o índice é válido
        local arrayLength
        arrayLength=$(yq eval ".${pkey} | length" "$file")
        if [ "$index" -lt 0 ] || [ "$index" -ge "$arrayLength" ]; then
            _error="$ERROR_INDEX_OUT_OF_BOUNDS"
            return 1
        fi

        # Extrai as keys do objeto no índice
        local keys
        mapfile -t keys < <(yq eval ".${pkey}[$index] | keys[]" "$file")

        #declare an associative array to store the key-value pairs
        unset -v _r
        unset _r
        declare -Ag _r
        for k in "${keys[@]}"; do
            # Remove aspas se houver no k
            k="${k%\"}"
            k="${k#\"}"

            local value
            value=$(yq eval ".${pkey}[$index].$k" "$file")
            # Remove aspas do value, se existir
            value="${value%\"}"
            value="${value#\"}"

            _r["$k"]="$value"
        done

        _error=""
        return 0
    }

    
    

# Se o script estiver sendo *sourced*, registre o autocompletion
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    complete -F _shu_autocomplete shu
    export SHU_PATH="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    return
fi


#Debug helping (integrattes with vscode launch.json and tasks.json): 
if [[ "$1" == "--debug-read-from-file" ]]; then
    #read first line from the file specified in the second argument
    firstLine=$(head -n 1 "$2")
    secondLine=$(head -n 2 "$2" | tail -n 1)
    cd "$firstLine"
    
    eval "shu.Main $secondLine"; retCode=$?
    exit $retCode
fi

shu.Main "$@"; retCode=$?
exit $retCode
