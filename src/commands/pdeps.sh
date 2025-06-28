#!/bin/bash


shu.depsMain(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.pdeps.Help
        return 0
    fi
    

    if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
        _error="$ERROR_COMMAND_REQUIRES_SHU_PROJECT"
        return 1
    fi
    

    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.pdeps.$func" "$@"
}

shu.pdeps.Help(){
    echo "pdeps <subcommand>         - Commands to manage dependencies of the project"
    echo "  subcommands:"
    echo "    get \"<url[@<checkout_to>][#<path>][as <name>][pack options]>\" [options]"  
    echo "                           - Get a package from a URL and add it to the project. If you are hooking this command (after the execution), it exports SHU_LAST_DEP_GET_FOLDER with the path to the package folder."
    echo "      options:"
    echo "        --not-recursive      - Do not restore dependencies of the package."
    echo "      @<checkout_to>         - Shu will checkout the repository to <checkout_to>."
    echo "      #<path>                - Shu will copy only the contents of the specified path (in the repository) to the package folder."
    echo "      as <name>              - Shu will name package folder to <name> instead of the repository name."
    echo "      pack options:"
    echo "        --allow-no-git         - allow a no git repository. Shu will try to find it in the filesystem or download it from the web. If a download could be done, the shu will try to extract it if has a supported extension (.zip, .tar.gz, .tar.bz2, .7z)."
    echo "        --not-recursive        - Do not restore dependencies of the package."
    echo "    restore                - Restore all dependencies from shu.yaml."
    echo "    clean                  - Remove all dependencies from shu.yaml."
    echo "  examples:"
    echo "    shu pdeps get 'https://github.com/rafael-tonello/SHU.git'"
    echo "                           - Get the SHU package from GitHub and add it to the project."
    echo "    shu pdeps get 'https://github.com/rafael-tonello/SHU.git@develop --not-recursive'"
    echo "                           - Get the SHU package from GitHub, checkout to develop branch and do not restore dependencies."
    echo "    shu pdeps get 'https://github.com/rafael-tonello/SHU.git@develop#/src/shellscript-fw/common"
    echo "                           - Get the SHU package from GitHub, checkout to develop branch, copy only the contents of src/shellscript-fw/common to the package folder."

}


shu.pdeps.Add(){
    shu.Main pdeps get "$@"
    return $?
}

#add a dependency to the project. The dependency should be a git repository.
#also export SHU_LAST_DEP_GET_FOLDER with path to the dependency folder.
shu.pdeps.Get(){ 
    #if no args, redirects to shu.pdeps.Restore 
    if [ "$#" -eq 0 ]; then
        shu.pdeps.Restore
        if [ "$_error" != "" ]; then
            _error="Error restoring dependencies: $_error"
            return 1
        fi
        return 0
    fi

    local url="$1"; shift;
    shu.initFolder

    #try to identify if user is providing 'url as package' separated..
    if [ "$1" == "as" ]; then
        url="$url $1 $2"; shift 2
    fi

    local originalUrl=$url
    
    shu.restoreDep "$url" "" ""; local depPath="$_r"
    export SHU_LAST_DEP_GET_FOLDER="$depPath"
    if [ "$_error" != "" ]; then
        _error="Error restoring dependency '$originalUrl': $_error"
        return 1
    fi

    shu.yaml.addArrayElement "shu.yaml" ".packages" "$url"
    if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
        _error="Error adding dependency '$originalUrl' to shu.yaml: $_error"
        return 1
    fi
    
    #enter dependecy package
    cd "$depPath"
    shu.Main psysdeps check
    cd -
    if [ "$_error" != "" ]; then
        printf "\033[0;33mWarning: The dependency '$originalUrl' requires some commands that are not found in the system. Please install them to use the dependency properly.\n Run 'shu psysdeps check' to see the list of missing commands.\033[0m\n"
    fi
    _error=""
    echo "Added/restored dependency '$originalUrl' to project '$SHU_PROJECT_NAME'."

    #recursive call for remain arguments
    if [[ "$#" -gt 0 && "$@" != "" ]]; then
        shu.pdeps.Get "$@"
        
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
}

shu.pdeps.Remove(){ local urlOrIndex="$1"; shift
    #if $1 is not an index, try to find it in the dependencies list
    local index=$urlOrIndex
    local url=$urlOrIndex
    if [[ ! "$urlOrIndex" =~ ^[0-9]+$ ]]; then
        shu.pdeps.findIndexByPartialUrl "$urlOrIndex"; local index="$_r"
        if [ "$_error" != "" ]; then
            _error="Error getting index of dependency '$urlOrIndex': $_error"
            return 1
        fi
    else
        #get url using the index
        shu.pdeps.getUrlByIndex "$index"; local url="$_r"
        if [ "$_error" != "" ]; then
            _error="Error getting url of dependency with index '$index': $_error"
            return 1
        fi
    fi

    shu.yaml.removeArrayElement "shu.yaml" ".packages" "$index"

    shu.pdeps.determine_Url_branch_folder_and_packageName "$url";
    if [ "$_error" != "" ]; then
        _error="Error determining url, branch, path and package name from '$url': $_error"
        return 1
    fi

    local url="$_r_url"
    local branch="$_r_branch"
    local path="$_r_path"
    local packageName="$_r_packageName"
    local destinationFolder="$SHU_PROJECT_ROOT_DIR/.shu/packages/$packageName"
    local notRecursive="$_r_notRecursive"

    if [ -d "$destinationFolder" ]; then
        #remove the package folder
        rm -rf "$destinationFolder"
        if [ $? -ne 0 ]; then
            _error="Error removing dependency folder '$destinationFolder': $?"
            return 1
        fi
        echo "Removed dependency '$url' from project."
    else
        _error="Dependency '$url' not found in the project."
        return 1
    fi

    _error=""
    #recursive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.pdeps.Remove "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
    return 0
}

#clean only dependencies. Use 'shu clean' instead.
shu.pdeps.Clean(){
    #remove ./.shu folder
    rm -rf "$SHU_PROJECT_ROOT_DIR/.shu"
    echo "Removed .shu folder"
}

#restore only dependencies. Use 'shu restore' instead.
shu.pdeps.Restore(){
    #restore all dependencies from shu.yaml
    if [ ! -f "shu.yaml" ]; then
        _error="$ERROR_NO_SHU_DIRECTORY"
        return 1
    fi

    mkdir -p "$(pwd)/.shu/packages"

    shu.yaml.getArray "shu.yaml" ".packages[]"; local packages=("${_r[@]}")
    if [ "$_error" != "" ]; then
        _error="Error getting dependencies from shu.yaml: $_error"
        return 1
    fi

    restoreErrors=""
    for dep in "${packages[@]}"; do
        shu.restoreDep "$dep" "" true
        if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
            if [ -n "$restoreErrors" ]; then
                restoreErrors="+ "
            fi
            restoreErrors="Error restoring dependency '$dep': $_error"
        fi
    done

    #check if --no-check-sysdepss or -ncc is not present in the arguments
    if [[ ! " $@ " =~ " --no-check-sysdepss " ]] && [[ ! " $@ " =~ " -ncc " ]]; then
        shu.Main psysdeps check
        if [ "$_error" != "" ]; then
            printf "\033[0;33mWarning: The dependency '$originalUrl' requires some commands that are not found in the system. Please install them to use the dependency properly.\n Run 'shu psysdeps check' to see the list of missing commands.\033[0m\n"
        fi
    fi
    
    if [ -n "$restoreErrors" -ne 0 ]; then
        _error="Error restoring dependencies from shu.yaml. Some dependencies may not be restored: $restoreErrors"
        return 1
    else 
        _error=""
        echo "All dependencies restored from shu.yaml"
    fi
    
    return 0
}

shu.pdeps.List(){
    shu.initFolder

    #get all dependencies from shu.yaml
    shu.yaml.getArray "shu.yaml" ".packages[]"; local packages=("${_r[@]}")
    if [ "$_error" != "" ]; then
        _error="Error getting dependencies from shu.yaml: $_error"
        return 1
    fi

    if [ "${#packages[@]}" -eq 0 ]; then
        echo "No dependencies found in the project."
        return 0
    fi

    for dep in "${packages[@]}"; do
        echo "$dep"
    done
}

#internal (private) functions {
    #download (clone) repository to <current directory>/.shu
    #
    #https://path.to/repo.git -> clone to .shu/packages/repo
    #https://path.to/repo.git@branch_or_tag -> clone to .shu/packages/repo and checkout branch_or_tag
    #https://path.to/repo.git#/path/to/dirName -> clone to a temp folder and copy the contents of dir to .shu/packages/dirName
    #https://path.to/repo.git@branch_or_tag#/path/to/dirName -> clone to a temp folder, checkout branch_or_tag and copy the contents of dir to .shu/packages/dirName
    #/folder/to/be/copied --alow-no-git -> copy the folder to .shu/packages/folderName
    #
    # additionaly, the string 'as <packageName>' can be used to specify the package name
    #
    #_r is set to the path of the cloned repository
    shu.restoreDep(){ local url=$1; 
                      #destinationFolder is also used to install packages (instead of adding it to a project)
                      local destinationFolder=${2:-$(realpath -m "$SHU_PROJECT_ROOT_DIR/.shu/packages")}; 
                      local ignoreAlreadyDoneError=${3:-false}
        
        shu.pdeps.determine_Url_branch_folder_and_packageName "$url"; 
        if [ "$_error" != "" ]; then
            _error="Error determining url, branch, path and package name from '$url': $_error"
            return 1
        fi

        local _recursive=true

        url="$_r_url"
        local branch="$_r_branch"
        local path="$_r_path"
        local packageName="$_r_packageName"
        local allowNoGit="$_r_allowNoGit"
        local notRecursive="$_r_notRecursive"

        if [ "$notRecursive" == "true" ]; then
            _recursive=false
        fi

        #check if destination folder exists, if not, create it
        if [ "$path" != "" ]; then
            shu.cloneAndGetSubFolder "$url" "$path" "$branch" "$destinationFolder/$packageName" "$allowNoGit"
            if [ "$_error" != "" ] && ([ "$_error" != "$ERROR_AREADY_DONE" ] || [ "$ignoreAlreadyDoneError" == "false" ]); then
                _error="Error cloning repository '$url' and get the subfolder '$path': $_error"
                return 1
            fi
        else
            shu.clone "$url" "$branch" "$destinationFolder/$packageName" "$allowNoGit"
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

        if [ "$_recursive" == "true" ]; then
            shu.pdeps.Restore --no-check-sysdepss
        fi
        
        cd "$currDir"
        if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ] && [ "$_error" != "$ERROR_NO_SHU_DIRECTORY" ]; then
            _error="Error restoring dependencies for package '$packageName': $_error"
            cd "$currDir"
            return 1
        fi
        _error=""

        _r="$destinationFolder/$packageName"
    }

    shu.cloneAndGetSubFolder(){ local url=$1; local path=$2; local branch=$3; local destinationPath="$4"; local _allowNoGit=${5:-false}
        #create a temp folder
        if [ -d "$destinationPath" ]; then
            _error="$ERROR_AREADY_DONE"
            return 1
        fi

        local tempDir="$(mktemp -u)$RANDOM"

        #echo "url: $url"
        #echo "branch: $branch"
        #echo "path: $path"
        #echo "destinationPath: $destinationPath"
        #echo "tempDir: $tempDir"

        shu.clone "$url" "$branch" "$tempDir" "$_allowNoGit"
        if [ "$_error" != "" ] && ([ "$_error" != "$ERROR_AREADY_DONE" ] || [ "$ignoreAlreadyDoneError" == "false" ]); then
            _error="Error cloning repository '$url': $_error"
            rm -rf "$tempDir"
            return 1
        fi

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

    shu.clone(){ local url=$1; local branch=$2; local dest=$3; local _allowNoGit=${4:-false}
        if [ -d "$dest" ]; then
            _error="$ERROR_AREADY_DONE"
            return 1
        fi

        if  [ "$_allowNoGit" == "true" ]; then
            if [[ -d  "$url" ]]; then
                cp -r "$url" "$dest"
                _error=""
                return 0
            else
                #check is an url and ends with .zip, .7z, .tar.gz or .tar.bz2
                if [[ "$url" =~ ^https?://.*\.(zip|7z|tar\.gz|tar\.bz2)$ ]]; then
                    #download the file to a temp folder
                    local tempFile="$(mktemp -u)$RANDOM"
                    #wget -q "$url" -O "$tempFile"
                    curl -sL "$url" -o "$tempFile"
                    if [ $? -eq 0 ]; then
                        #check the file extension and extract it
                        case "$tempFile" in
                            *.zip)
                                unzip -q "$tempFile" -d "$dest"
                                if [ $? -eq 0 ]; then
                                    rm -f "$tempFile"
                                    _error=""
                                    return 0
                                fi
                                rm -f "$tempFile"
                                ;;
                            *.7z)
                                7z x -o"$dest" "$tempFile" > /dev/null 2>/tmp/shu-7z-error.log
                                if [ $? -eq 0 ]; then
                                    rm -f "$tempFile"
                                    _error=""
                                    return 0
                                fi
                                rm -f "$tempFile"
                                ;;
                            *.tar.gz)
                                tar -xzf "$tempFile" -C "$dest"
                                if [ $? -eq 0 ]; then
                                    rm -f "$tempFile"
                                    _error=""
                                    return 0
                                fi
                                rm -f "$tempFile"
                                ;;
                            *.tar.bz2)
                                tar -xjf "$tempFile" -C "$dest"
                                if [ $? -eq 0 ]; then
                                    rm -f "$tempFile"
                                    _error=""
                                    return 0
                                fi
                                rm -f "$tempFile"
                                ;;
                        esac
                        rm "$tempFile"
                    else
                        _error="error downloading file '$url': $?"
                        return 1
                    fi
                fi
            fi
        fi

        git clone --recursive "$url" "$dest" > /dev/null 2>/tmp/shu-clone-error.log
        if [ $? -ne 0 ]; then
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

    shu.pdeps.determine_Url_branch_folder_and_packageName(){ local url=$1; local destinationFolder=${2:-$(realpath -m "$SHU_PROJECT_ROOT_DIR/.shu/packages")}; local ignoreAlreadyDoneError=${3:-false}
        #check if url contains 'as <packageName>'
        local packageName="";
        local branch="";
        local path="";
        local forcedPackageName="";
        local _allowNoGit=false
        local _notRecursive=false

        #check if url contains --allow-no-git
        if [[ $url == *" --allow-no-git"* ]]; then
            _allowNoGit=true
            
            url="${url//' --allow-no-git'/}"
        else
            _allowNoGit=false
        fi

        #check if url contains --allow-no-git
        if [[ $url == *" --not-recursive"* ]]; then
            _notRecursive=true
            
            url="${url//' --not-recursive'/}"
        else
            _notRecursive=false
        fi

        if [[ $url == *" as "* ]]; then
            forcedPackageName=${url##* as }
            url=${url%% as *}
        fi

        
        #check if url contains '#'
        if [[ $url == *"#"* ]]; then
            path=${url#*#}
            url=${url%%#*}

            packageName="$(basename "$path")"
            
            if [ -d "$destinationFolder/$path" ]; then
                _error="Destination folder '$path' already exists. Please remove it, specify a different destination folder or use 'as <name>' to use a name for this dependency."
                return 1
            fi
        fi
        
        #check if url contains '@'
        if [[ $url == *"@"* ]]; then
            #'@' should be after at least one '/' (because it can be just a git ssh uri, like git@github.com)
            arrobaPosition=$(expr index "$url" "@")
            firstSlashPosition=$(expr index "$url" "/")
            if [ $arrobaPosition -gt $firstSlashPosition ]; then
                branch=${url#*@}
                url=${url%%@*}
            fi
        fi
        
        if [ "$packageName" == "" ]; then
        
            packageName=$(basename "$url")

            #remove a possible .git from the packageName
            if [[ "$packageName" == *.git ]]; then
                packageName="${packageName%.git}"
            fi
        fi

        if [ "$forcedPackageName" != "" ]; then
            packageName="$forcedPackageName"
        fi

        #echo ""
        #echo "==============================="
        #echo "url: $url"
        #echo "branch: $branch"
        #echo "path: $path"
        #echo "packageName: $packageName"
        #echo "destinationFolder: $destinationFolder"
        #echo "==============================="

        _r=("$url" "$branch" "$path" "$packageName" "$destinationFolder" "$_allowNoGit" "$_notRecursive")
        _r_url="${_r[0]}"
        _r_branch="${_r[1]}"
        _r_path="${_r[2]}"
        _r_packageName="${_r[3]}"
        _r_destinationFolder="${_r[3]}"
        _r_allowNoGit="${_r[5]}"
        _notRecursive="${_r[6]}"
    }

    shu.pdeps.findIndexByPartialUrl(){ local url="$1"
        shu.yaml.getArray "shu.yaml" ".packages[]"; local packages=("${_r[@]}")
        if [ "$_error" != "" ]; then
            _error="Error getting dependencies from shu.yaml: $_error"
            return 1
        fi

        local result=()
        for i in "${!packages[@]}"; do
            #check if package begins or ends with $url
            if [[ "${packages[$i]}" == "$url"* ]] || [[ "${packages[$i]}" == *"$url" ]]; then
                result+=("$i")
            fi
        done

        if [ "${#result[@]}" -eq 1 ]; then
            _error=""
            _r="${result[0]}"
            return 0
        elif  [ "${#result[@]}" -gt 1 ]; then
            _error="Multiple dependencies found for '$url': ${result[*]}. Please specify the index of the dependency you want to remove."
            _r="-1"
            return 1
        else
            _error="Dependency '$url' not found in shu.yaml"
            _r="-1"
            return 1
        fi
    }

    shu.pdeps.getUrlByIndex(){ local index="$1"

        shu.yaml.getArray "shu.yaml" ".packages[]"; local packages=("${_r[@]}")
        if [ "$_error" != "" ]; then
            _error="Error getting dependencies from shu.yaml: $_error"
            _r=""
            return 1
        fi

        if [ "$index" -lt 0 ] || [ "$index" -ge "${#packages[@]}" ]; then
            _error="Index '$index' is out of bounds. Please provide a valid index."
            _r=""
            return 1
        fi

        _r="${packages[$index]}"
        _error=""
        return 0
    }
#}

shu.depsMain "$@"
return $?
