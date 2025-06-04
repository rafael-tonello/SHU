#!/bin/bash

ERROR_AREADY_DONE="already done"
ERROR_NO_SHU_DIRECTORY="is not shu project/directory. No shu.yaml found"

shu.main(){ local cmd="$1"; shift
    shu.checkPrerequisites
    if [ "$_error" != "" ]; then
        shu.printError "Shu error: $_error"
        return 1
    fi

    local capitalizedCmd=$(echo "$cmd" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shu.$capitalizedCmd "$@"

    #if $_error is not empty or return code is not 0, print error message
    if [ "$?" -ne 0 ] || [ "$_error" != "" ]; then
        shu.printError "Shu error: $_error"
        return 1
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

#Shu-cli direct commands (commands with no sub-cli) {
    #Initialize a new Shu project in the current directory by creating a shu.yaml file.
    shu.Init(){ local projectName=${1:-$(basename "$(pwd)")}
        shu.initFolder "$projectName"

        #TODO: clone miscellaneous to ./shu/packages/shu-misc
        #TODO: create main.sh file
        #TODO: add 'source ./shu/packages/shu-misc/shu-shu.sh' to the main file

        echo "Initialized Shu project '$projectName'."
    }

    #deletes the .shu folder
    shu.Clean(){
        shu.Depclean
    }

    #restore all dependencies from shu.yaml. If .shu folder already exists, the process is aborted
    shu.Restore(){
        shu.Deprestore
    }

    #deletes .shu folder and restores it ('runs shu clean' and 'shu restore')
    shu.Refresh(){
        shu.Clean
        shu.Restore
    }

    #you can specify partes of path to prevent colision with other scripts names
    #
    #Note: this function will find any script in the ./shu/packages/ folder, not only the ones in the main section of shu.yaml.
    #Note: All found scripts will be run, so if you have multiple scripts with the same name in different packages, they will all be run.
    shu.Runtool(){ local scriptName="$1"; shift
        if [ "$scriptName" == "" ]; then
            _error="No script name provided. Please provide a script name to run."
            return 1
        fi

        #find the '$scriptName' and '$scriptName.sh' in all .shu/packages/
        local foundScripts=$(find .shu/packages/ -type f \( -name "$scriptName" -o -name "$scriptName.sh" \) -executable)
        
        if [ "$foundScripts" == "" ]; then
            _error="Script '$scriptName' not found in any package."
            return 1
        fi

        for script in $foundScripts; do
            #check if script is executable
            if [ ! -x "$script" ]; then
                continue
            fi

            shu.runScript "$script" "$@"
            if [ "$_error" != "" ]; then
                shu.printError "error running script '$script': $_error"
                return 1
            fi
        done
    }

    shu.Test(){
        #check if argCount is 0

        if [ "$#" -eq 0 ]; then
            shu.runFolderTests "./"
        else
            files=();
            folders=();
            recursive=false;
            for arg in "$@"; do
                if [[ "$arg" == "-r" || "$arg" == "--recursive" ]]; then
                    recursive=true;
                elif [ -d "$arg" ]; then
                    folders+=("$arg");
                elif [[ "$1" == *".test."* ]]; then
                    files+=("$arg");
                else
                    #check if the file exists
                    if [ -f "$arg" ]; then
                        local lastDotIndex=$(expr index "$1" .)
                        local fName="${1:0:lastDotIndex-1}"
                        local fExt="${1:lastDotIndex}"
                        fName=$fName".test"$fExt
                        if [ -f "$fName" ]; then
                            files+=("$fName");
                        else
                            shu.printError "Test file for '$arg' ($fName) not found"
                        fi 
                    else
                        shu.printError "tests for '$arg' not found"
                    fi
                fi
            done

            for file in "${files[@]}"; do
                shu.runTestFile "$file"
                if [ "$_error" != "" ]; then
                    shu.printError "Error running test file '$file': $_error"
                    return 1
                fi
            done

            for folder in "${folders[@]}"; do
                shu.runFolderTests "$folder" "$recursive"
                if [ "$_error" != "" ]; then
                    shu.printError "Error running tests in folder '$folder': $_error"
                    return 1
                fi
            done
        fi

    }

    shu.Help(){
        echo "Shu CLI - A package manager for shellscripting"
        echo "Usage: shu <command> [options]"
        echo "Commands:"
        echo "  init [projectName]   Initialize a new Shu project in the current directory."
        echo "  get <url>            Get a package from a URL and add it to the project."
        echo "  restore              Restore all dependencies from shu.yaml."
        echo "  clean                Remove the .shu folder and all installed packages."
        echo "  refresh              Clean and restore all dependencies from shu.yaml."
        echo "  setmain <scriptName> Set a script as the main script for the project."
        echo "  run [scriptName]     Run the main script or a specific script."
        echo "  install <url>        Install a package from a URL."
        echo "  uninstall <packageOrCommandName> "
        echo "                       Uninstall a package or command."
        echo "  runtool <scriptName> Find scripts named <scriptName> in ./shu/packages/ and run them."
        echo ""
        echo "Additional information: Virtually, shu can install any git repository to you project."
    }

    #clone $url to ~/.local/shu/installed
    #create a symlink for each script in the main section of shu.yaml to ~/.local/shu/bin
    #changes .bashrc to add ~/.local/shu/bin to PATH if not already present
    #add ~/.local/shu/bin to PATH if not already present
    shu.Install(){ local url="$1"; shift
        mkdir -p $HOME/.local/shu/installed
        mkdir -p $HOME/.local/shu/bin

        restoreDep $url "$HOME/.local/shu/installed"; local destination="$_r"
        if [ "$_error" != "" ]; then
            shu.Uninstall "$(basename "$destination")"
            _error="error installing package: $_error"
            return 1
        fi

        cd "$destination"
        if [ ! -f "shu.yaml" ]; then
            shu.Uninstall "$(basename "$destination")"
            _error="shu.yaml file not found in the destination directory"
            return 1
        fi

        shu.yaml.getArray "shu.yaml" ".main[]"; local mainScripts=("$_r")
        if [ "$mainScriptList" == "" ]; then
            shu.Uninstall "$(basename "$destination")"
            _error="No main scripts found in shu.yaml. Please add scripts to the main section."
            return 1
        fi

        for script in $mainScriptList; do
            if [ ! -f "$script" ]; then
                shu.printError "error installing command for script '$script'. Script not found in the package. Please check the main section of shu.yaml."
                return 1
            fi
            
            #make script executable
            chmod +x "$script"
            
            #remove extension from script name
            local scriptNameWithoutExt="${script%.*}"

            #create symlink in ~/.local/shu/bin
            ln -sf "$destination/$script" "$HOME/.local/shu/bin/$scriptNameWithoutExt"

            echo "Installed command '$scriptNameWithoutExt' from package $(basename "$destination")"
        done

        #add ~/.local/shu/bin to PATH if not already present
        if ! grep -q "$HOME/.local/shu/bin" "$HOME/.bashrc"; then
            echo "export PATH=\"\$PATH:$HOME/.local/shu/bin\"" >> "$HOME/.bashrc"
            echo "Added ~/.local/shu/bin to PATH in ~/.bashrc"
            source "$HOME/.bashrc"
        fi
        if ! grep -q "$HOME/.local/shu/bin" "$HOME/.profile"; then
            echo "export PATH=\"\$PATH:$HOME/.local/shu/bin\"" >> "$HOME/.profile"
            echo "Added ~/.local/shu/bin to PATH in ~/.profile"
            source "$HOME/.profile"
        fi
        _error=""
    }

    shu.Uninstall(){ local packageOrCommandName="$1"
        shu.getPackagePath "$packageOrCommandName"; local packagePath="$_r"
        if [ "$_error" != "" ]; then
            _error="error unistalling a package: $_error"
            return 1
        fi

        #ask for confirmation
        read -p "Are you sure you want to uninstall '$(basename "$packagePath")'? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Uninstall cancelled."
            return 0
        fi

        cd "$packagePath"
        #get the main scripts from shu.yaml

        shu.yaml.getArray "shu.yaml" ".main[]"; local mainScriptList="$_r"
        for script in $mainScriptList; do
            #remove symlink from ~/.local/shu/bin
            local scriptNameWithoutExt="${script%.*}"
            if [ -L "$HOME/.local/shu/bin/$scriptNameWithoutExt" ]; then
                rm "$HOME/.local/shu/bin/$scriptNameWithoutExt"
                echo "Removed command '$scriptNameWithoutExt' from ~/.local/shu/bin"
            else
                echo "Command '$scriptNameWithoutExt' not found in ~/.local/shu/bin"
            fi
        done

        #remove the package directory
        if [ -d "$packagePath" ]; then
            rm -rf "$packagePath"
            echo "Removed package '$packagePath'"
        else
            _error="package '$packagePath' not found"
        fi

    }

    shu.Setmain(){ shu.mainFileAdd "$@"; } #alias for shu.mainFileAdd

    shu.Run(){ shu.Mainfilerun "$@"; } #alias for shu.mainFileRun

    shu.Get(){ shu.Depget "$@"; } #alias for shu.DepGet

    #internal (private) functions {
        shu.initFolder(){
            #project name is in the first argument. If not present, use current directory name
            local projectName=${1:-$(basename "$(pwd)")}

            mkdir -p .shu

            if  [ ! -f "shu.yaml" ]; then
                echo "name: \"$projectName\"" > shu.yaml
                echo "main: " >> shu.yaml
                echo "deps: " >> shu.yaml

                #check if .gitignore exists, if not, create it
                if [ ! -f ".gitignore" ]; then
                    echo ".shu/" > .gitignore
                else
                    #check if .shu/ is already in .gitignore
                    if ! grep -q ".shu/" ".gitignore"; then
                        echo ".shu/" >> .gitignore
                    fi
                fi
            fi
        }

        shu.runFolderTests(){ local directory="$1"; local _recursive=${2:-false}
            if [ ! -d "$directory" ]; then
                _error="Directory '$directory' not found."
                return 1
            fi

            #find all files with .test. in the name in the directory
            local testFiles=$(find "$directory" -type f -name "*.test.*")
            
            if [ "$testFiles" == "" ]; then
                return 0
            fi

            for file in $testFiles; do
                shu.runTestFile "$file"
                if [ "$_error" != "" ]; then
                    shu.printError "Error running test file '$file': $_error"
                fi
            done

            if [ "$_recursive" == "true" ]; then
                #find all subdirectories and run tests in them
                local subdirs=$(find "$directory" -type d)
                for subdir in $subdirs; do
                    if [ "$subdir" != "$directory" ]; then
                        shu.runFolderTests "$subdir" true
                        if [ "$_error" != "" ]; then
                            shu.printError "Error running tests in folder '$subdir': $_error"
                        fi
                    fi
                done
            fi
        }

        shu.runTestFile(){ local file="$1"
            if [ ! -f "$file" ]; then
                _error="Test file '$file' not found."
                return 1
            fi

            #check if file is executable
            if [ ! -x "$file" ]; then
                _error="Test file '$file' is not executable. Please make it executable with 'chmod +x $file'."
                return 1
            fi

            echo "----[ Running tests of file '$file' ]----"
            #run the test file
            "$file"
            if [ $? -ne 0 ]; then
                _error="Test file '$file' failed."
                return 1
            fi
            _error=""

        }
    #}
#}

#mainfiles management sub-cli
    shu.Mainfile(){
        local subCmd="$1"; shift
        case "$subCmd" in
            "add")
                shu.mainFileAdd "$@"
                ;;
            "remove")
                shu.mainFileRemove "$@"
                ;;
            "list")
                shu.mainFileList "$@"
                ;;
            "run")
                shu.mainFileRun "$@"
                ;;
            *)
                _error="Unknown subcommand '$subCmd' for 'shu mainfile'. Available subcommands: add, remove, list."
                return 1
                ;;
        esac
    }
    shu.Mainfiles(){ shu.Mainfile "$@"; } #alias for shu.MainFile

    #add a script to the main section of shu.yaml
    shu.mainFileAdd(){ local scriptName="$1"; shift
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
        
        #check if file is already added to the 'main' section of shu.yaml (user shu.yaml.listContains)
        shu.yaml.listContains "shu.yaml" ".main" "$scriptName"
        if [ "$_r" == "true" ]; then
            _error="Script '$scriptName' is already set as main. Please provide a different script name."
            return 1
        fi

        #add script to the main section
        shu.yaml.append "shu.yaml" ".main" "$scriptName"
        if [ "$_error" != "" ]; then
            _error="Error adding script '$scriptName' to main section of shu.yaml: $_error"
            return 1
        fi

        shu.yaml.get "shu.yaml" ".name"; local projectName="$_r"
        echo "Script '$scriptName' set as a main script for project '$projectName'."
        _error=""
    }
    
    #runs the <scriptName>. If no script name is provided, it will run all scripts in the main section of shu.yaml.
    shu.Mainfilerun(){ local scriptName="$1"; shift
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

        _error=""  
    }

    shu.mainFileRemove(){ local scriptName="$1"; shift
        if [ "$scriptName" == "" ]; then
            _error="No script name provided. Please provide a script name to remove from main section."
            return 1
        fi
        shu.initFolder

        #check if script is in the main section of shu.yaml
        shu.yaml.listContains "shu.yaml" ".main" "$scriptName"
        if [ "$_r" == "false" ]; then
            _error="Script '$scriptName' is not set as main. Please provide a valid script name."
            return 1
        fi

        #remove script from the main section
        yq eval -i ".main |= del(.[] | select(. == \"$scriptName\"))" "shu.yaml"
        if [ "$_error" != "" ]; then
            _error="Error removing script '$scriptName' from main section of shu.yaml: $_error"
            return 1
        fi

        shu.yaml.get "shu.yaml" ".name"; local projectName="$_r"
        echo "Script '$scriptName' removed from main section of project '$projectName'."
        _error=""
    }

    shu.mainFileList(){
        shu.initFolder

        #get all main scripts from shu.yaml
        shu.yaml.getArray "shu.yaml" ".main[]"; local mainScripts=("$_r")
        if [ "$_error" != "" ]; then
            _error="Error getting main scripts from shu.yaml: $_error"
            return 1
        fi

        if [ "${#mainScripts[@]}" -eq 0 ]; then
            echo "No main scripts set in the project."
            return 0
        fi

        echo "Main scripts in the project:"
        for script in "${mainScripts[@]}"; do
            echo "- $script"
        done
    }

    shu.runScript(){ local scriptName="$1"; shift
        if [ -f "$scriptName" ]; then
            #check if script is executable
            if [ ! -x "$scriptName" ]; then
                _error="Script '$scriptName' is not executable. Please make it executable with 'chmod +x $scriptName'."
                return 1
            fi
            #run the script
            ./"$scriptName" "$@"
        else
            _error="Script '$scriptName' not found."
            return 1
        fi
    }
#}

#dependecy management sub-cli #{
    shu.Dep(){
        local subCmd="$1"; shift
        case "$subCmd" in
            "get")
                shu.Depget "$@"
                ;;
            "remove")
                shu.Depremove "$@"
                ;;
            "list")
                shu.Deplist "$@"
                ;;
            *)
                _error="Unknown subcommand '$subCmd' for 'shu dep'. Available subcommands: get, restore, clean, refresh, install, uninstall."
                return 1
                ;;
        esac
    }

    #add a dependency to the project. The dependency should be a git repository.
    shu.Depget(){ local url="$@";
        shu.initFolder

        local originalUrl=$url

        shu.yaml.append "shu.yaml" ".deps" "$url"
        if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
            _error="Error adding dependency '$originalUrl' to shu.yaml: $_error"
            return 1
        fi

        shu.restoreDep "$url"
        echo "returned from restoreDep with _r='$_r' and _error='$_error'"
        if [ "$_error" != "" ]; then
            _error="Error restoring dependency '$originalUrl': $_error"
            return 1
        fi

        _error=""
        shu.yaml.get "shu.yaml" ".name"; local projectName="$_r"
        echo "Added/restored dependency '$originalUrl' to project '$projectName'."
    }

    #clean only dependencies. Use 'shu clean' instead.
    shu.Depclean(){
        #remove ./.shu folder
        rm -rf .shu
        echo "Removed .shu folder"
    }

    #restore only dependencies. Use 'shu restore' instead.
    shu.Deprestore(){
        #restore all dependencies from shu.yaml
        if [ ! -f "shu.yaml" ]; then
            _error="$ERROR_NO_SHU_DIRECTORY"
            return 1
        fi

        shu.yaml.getArray "shu.yaml" ".deps[]"; local deps=("${_r[@]}")
        if [ "$_error" != "" ]; then
            _error="Error getting dependencies from shu.yaml: $_error"
            return 1
        fi

        for dep in "${deps[@]}"; do
            echo "---->restoring dep '$dep'"
            shu.restoreDep "$dep" "" true
            if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
                shu.printError "Error restoring dependency '$dep': $_error"
            fi
        done

        echo "All dependencies restored from shu.yaml"

        _error=""

    }

    #internal (private) functions {
        #download (clone) repository to <current directory>/.shu
        #
        #https://path.to/repo.git -> clone to .shu/packages/repo
        #https://path.to/repo.git@branch_or_tag -> clone to .shu/packages/repo and checkout branch_or_tag
        #https://path.to/repo.git#/path/to/dirName -> clone to a temp folder and copy the contents of dir to .shu/packages/dirName
        #https://path.to/repo.git@branch_or_tag#/path/to/dirName -> clone to a temp folder, checkout branch_or_tag and copy the contents of dir to .shu/packages/dirName
        #
        # additionaly, the string 'as <packageName>' can be used to specify the package name
        #
        #_r is set to the path of the cloned repository
        shu.restoreDep(){ local url=$1; local destinationFolder=${2:-$(realpath -m "$(pwd)/.shu/packages")}; local ignoreAlreadyDoneError=${3:-false}
            #check if url contains 'as <packageName>'
            local packageName="";
            local branch="";
            local path="";

            local forcedPackageName="";
            if [[ $url == *" as "* ]]; then
                forcedPackageName=${url##* as }
                url=${url%% as *}
            fi

            
            #check if url contains '#'
            if [[ $url == *"#"* ]]; then
                path=${url#*#}
                url=${url%%#*}

                
                packageName="$(basename "$path")"
                
                echo 'if [ -d "'$destinationFolder'/'$path'" ]; then'
                if [ -d "$destinationFolder/$path" ]; then
                    _error="Destination folder '$path' already exists. Please remove it, specify a different destination folder or use 'as <name>' to use a name for this dependency."
                    return 1
                fi
            fi
            
            #check if url contains '@'
            if [[ $url == *"@"* ]]; then
                branch=${url#*@}
                url=${url%%@*}
            fi
            
            if [ "$packageName" == "" ]; then
            
                packageName=$(basename "$url")

                #check if url contains .git
                if [[ $url == *.git ]]; then
                    packageName=${packageName%.git}
                fi
            fi

            if [ "$forcedPackageName" != "" ]; then
                packageName="$forcedPackageName"
            fi

            echo ""
            echo "==============================="
            echo "url: $url"
            echo "branch: $branch"
            echo "path: $path"
            echo "packageName: $packageName"
            echo "destinationFolder: $destinationFolder"
            echo "==============================="

            #check if destination folder exists, if not, create it

            if [ "$path" != "" ]; then
                shu.cloneAndGetSubFolder "$url" "$path" "$branch" "$destinationFolder/$packageName"
                if [ "$_error" != "" ] && ([ "$_error" != "$ERROR_AREADY_DONE" ] || [ "$ignoreAlreadyDoneError" == "false" ]); then
                    _error="Error cloning repository '$url' and get the subfolder '$path': $_error"
                    return 1
                fi
            else
                shu.clone "$url" "$branch" "$destinationFolder/$packageName"
                if [ "$_error" != "" ] && ([ "$_error" != "$ERROR_AREADY_DONE" ] || [ "$ignoreAlreadyDoneError" == "false" ]); then
                    _error="Error cloning repository '$url': $_error"
                    return 1
                fi
            fi

            #get all main scripts from shu.yaml in the package
            if [ -f "$destinationFolder/$packageName/shu.yaml" ]; then
                shu.yaml.getArray "$destinationFolder/$packageName/shu.yaml" ".main[]"; local mainScriptList="$_r"
                
                if [ "$mainScriptList" == "" ]; then
                    _error="No main scripts found in shu.yaml of package '$packageName'. Please add scripts to the main section."
                    return 1
                fi

                for script in $mainScriptList; do
                    chmod +x "$destinationFolder/$packageName/$script"
                done
            fi

            local currDir=$(pwd)
            if [ ! -d "$destinationFolder/$packageName" ]; then
                _error="package '$packageName' not found in destination folder '$destinationFolder' after clone. (??)"
                cd "$currDir"
                return 1
            fi
            cd "$destinationFolder/$packageName"

            shu.Restore
            
            cd "$currDir"
            if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ] && [ "$_error" != "$ERROR_NO_SHU_DIRECTORY" ]; then
                _error="Error restoring dependencies for package '$packageName': $_error"
                cd "$currDir"
                return 1
            fi
            _error=""

            _r="$destinationFolder/$packageName"
        }

        shu.cloneAndGetSubFolder(){ local url=$1; local path=$2; local branch=$3; local destinationPath="$4"
            #create a temp folder
            if [ -d "$destinationPath" ]; then
                _error="$ERROR_AREADY_DONE"
                return 1
            fi

            local tempDir="$(mktemp -u)$RANDOM"

            echo "detinationPath: $destinationPath"


            #echo "url: $url"
            #echo "branch: $branch"
            #echo "path: $path"
            #echo "destinationPath: $destinationPath"
            #echo "tempDir: $tempDir"

            shu.clone "$url" "$branch" "$tempDir"
            if [ -d "$tempDir/$path" ]; then
                #copy the contents of the subfolder to .shu/packages/<projectName>
                mkdir -p "$destinationPath/"

                cp -r "$tempDir/$path/"* "$destinationPath/"
                rm -rf "$tempDir"
            else
                _error="subfolder '$path' does not exist in the repository."
                rm -rf "$tempDir"
                return 1
            fi
            _error=""
        }

        shu.clone(){ local url=$1; local branch=$2; local dest=$3
            if [ -d "$dest" ]; then
                _error="$ERROR_AREADY_DONE"
                return 1
            fi

            echo 'git clone --recursive "'$url'" "'$dest'"'
            git clone --recursive "$url" "$dest" > /dev/null 2>/tmp/shu-clone-error.log
            if [ $? -ne 0 ]; then
                echo 4444
                _error="error runing git clone: $(cat /tmp/shu-clone-error.log)"
                rm /tmp/shu-clone-error.log
                return 1
            fi
            
            git config --global --add safe.directory "$dest" > /dev/null 2>/tmp/shu-safe-dir-error.log
            if [ $? -ne 0 ]; then
                _error="error adding '$dest' to safe directories: $(cat /tmp/shu-safe-dir-error.log)"
                rm /tmp/shu-safe-dir-error.log
                return 1
            fi

            if [ "$branch" != "" ]; then
                local retFolder="$(pwd)"
                #echo "ret folder: $retFolder"
                cd "$dest"
                git checkout "$branch" > /dev/null 2>/tmp/shu-checkout-error.log
                if [ $? -ne 0 ]; then
                    _error="error checking out branch '$branch': $(cat /tmp/shu-checkout-error.log)"
                    rm /tmp/shu-checkout-error.log
                    cd "$retFolder"
                    return 1
                fi

                cd "$retFolder"
            fi
            #delete all .git folders in the destination
            find "$dest" -type d -name ".git" -exec rm -rf {} +

            _error=""
        }
    #}    
#}

#functions for manipulating yaml files {
    #return 0 if the key exists in the yaml file, 1 otherwise. Also sets _r to 'true' or 'false'
    shu.yaml.containsKey(){ local file="$1"; local key="$2"
        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        #check if the key exists in the yaml file
        if yq eval ".\"$key\"" "$file" > /dev/null 2>&1; then
            _r="true"
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

    #erase the value of the key in the yaml file and set it to the value provided
    shu.yaml.set() {
        local file="$1"
        local key="$2"
        local value="$3"

        if [ ! -f "$file" ]; then
            _error="File '$file' not found."
            return 1
        fi

        #check if yq is installed
        if ! command -v yq &> /dev/null; then
            _error="yq is not installed. Please install yq (Mike Farah's) to use this function."

            return 1
        fi
        yq eval -i ".$key = \"$value\"" "$file"

        if [ $? -ne 0 ]; then
            _error="Error setting key '$key' to value '$value' in file '$file'."
            return 1
        fi

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

        if [ $? -ne 0 ]; then
            _error="Error appending value '$value' to key '$key' in file '$file'."
            return 1
        fi

        _error=""
    }
#}

shu.main "$@"; retCode=$?
echo "retCode: $retCode"
exit $retCode
