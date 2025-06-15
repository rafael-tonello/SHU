#!/bin/bash


shu.depMain(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.dep.Help
        return 0
    fi
    
    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.dep.$func" "$@"
}

shu.dep.Help(){
    echo "dep <subcommand>         - Commands to manage dependencies of the project"
    echo "  subcommands:"
    echo "    get <url>            - Get a package from a URL and add it to the project."
    echo "    restore              - Restore all dependencies from shu.yaml."
    echo "    clean                - Remove all dependencies from shu.yaml."
}

#add a dependency to the project. The dependency should be a git repository.
shu.dep.Get(){ 
    #check if $1 inits with '-'

    #check if '--not-recursive' is present in arguments
    if [[ "$@" == *"--not-recursive"* ]]; then
        local notRecursive=true
        #remove '--not-recursive' from arguments
        set -- "${@/--not-recursive/}"
    else
        local notRecursive=false
    fi
    

    local url="$1"; shift;
    shu.initFolder

    #try to identify if user is providing 'url as package' separated..
    if [ "$1" == "as" ]; then
        url="$url $1 $2"; shift 2
    fi

    local originalUrl=$url
    
    shu.restoreDep "$url" "" "" $notRecursive; local depPath="$_r"

    if [ "$_error" != "" ]; then
        _error="Error restoring dependency '$originalUrl': $_error"
        return 1
    fi

    shu.yaml.append "shu.yaml" ".packages" "$url"
    if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
        _error="Error adding dependency '$originalUrl' to shu.yaml: $_error"
        return 1
    fi
    
    #enter dependecy package
    cd "$depPath"
    shu.main cmddep check
    cd -
    if [ "$_error" != "" ]; then
        printf "\033[0;33mWarning: The dependency '$originalUrl' requires some commands that are not found in the system. Please install them to use the dependency properly.\n Run 'shu cmddep check' to see the list of missing commands.\033[0m\n"
    fi
    _error=""
    shu.yaml.get "shu.yaml" ".name"; local projectName="$_r"
    echo "Added/restored dependency '$originalUrl' to project '$projectName'."

    #recursive call for remain arguments
    if [[ "$#" -gt 0 && "$@" != "" ]]; then
        if  [ "$notRecursive" == "true" ]; then
            shu.dep.Get "$@" "--not-recursive"
        else
            shu.dep.Get "$@"
        fi

        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
}

shu.dep.Remove(){ local urlOrIndex="$1"; shift
    #if $1 is not an index, try to find it in the dependencies list
    local index=$urlOrIndex
    local url=$urlOrIndex
    if [[ ! "$urlOrIndex" =~ ^[0-9]+$ ]]; then
        shu.dep.findIndexByPartialUrl "$urlOrIndex"; local index="$_r"
        if [ "$_error" != "" ]; then
            _error="Error getting index of dependency '$urlOrIndex': $_error"
            return 1
        fi
    else
        #get url using the index
        shu.dep.getUrlByIndex "$index"; local url="$_r"
        if [ "$_error" != "" ]; then
            _error="Error getting url of dependency with index '$index': $_error"
            return 1
        fi
    fi

    shu.yaml.removeArrayElement "shu.yaml" ".packages" "$index"

    shu.dep.determine_Url_branch_folder_and_packageName "$url";
    if [ "$_error" != "" ]; then
        _error="Error determining url, branch, path and package name from '$url': $_error"
        return 1
    fi

    local url="$_r_url"
    local branch="$_r_branch"
    local path="$_r_path"
    local packageName="$_r_packageName"
    local destinationFolder="$(shu.getShuProjectRoot_absolute; echo "$_r")/.shu/packages/$packageName"

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
        shu.dep.Remove "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
    return 0
}

#clean only dependencies. Use 'shu clean' instead.
shu.dep.Clean(){
    #remove ./.shu folder
    rm -rf .shu
    echo "Removed .shu folder"
}

#restore only dependencies. Use 'shu restore' instead.
shu.dep.Restore(){
    #restore all dependencies from shu.yaml
    local returnCode=0
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

    for dep in "${packages[@]}"; do
        shu.restoreDep "$dep" "" true
        if [ "$_error" != "" ] && [ "$_error" != "$ERROR_AREADY_DONE" ]; then
            shu.printError "Error restoring dependency '$dep': $_error"
            returnCode=1    
        fi
    done

    #check if --no-check-cmddeps or -ncc is not present in the arguments
    if [[ ! " $@ " =~ " --no-check-cmddeps " ]] && [[ ! " $@ " =~ " -ncc " ]]; then
        shu.main cmddep check 
        if [ "$_error" != "" ]; then
            printf "\033[0;33mWarning: The dependency '$originalUrl' requires some commands that are not found in the system. Please install them to use the dependency properly.\n Run 'shu cmddep check' to see the list of missing commands.\033[0m\n"
        fi
    fi
    echo ""
    if [ "$returnCode" -ne 0 ]; then
        _error="Error restoring dependencies from shu.yaml. Some dependencies may not be restored."
    else 
        _error=""
        echo "All dependencies restored from shu.yaml"
    fi
    
    return $returnCode

}

shu.dep.List(){
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

    echo "Project dependencies:"
    for dep in "${packages[@]}"; do
        echo "- $dep"
    done
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
    shu.restoreDep(){ local url=$1; 
                      #destinationFolder is also used to install packages (instead of adding it to a project)
                      local destinationFolder=${2:-$(realpath -m "$(shu.getShuProjectRoot_absolute; echo "$_r")/.shu/packages")}; 
                      local ignoreAlreadyDoneError=${3:-false}
                      local _recursive=${4:-true}
        
        shu.dep.determine_Url_branch_folder_and_packageName "$url"; 
        if [ "$_error" != "" ]; then
            _error="Error determining url, branch, path and package name from '$url': $_error"
            return 1
        fi

        url="$_r_url"
        local branch="$_r_branch"
        local path="$_r_path"
        local packageName="$_r_packageName"

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

        if [ "$_recursive" == "true" ]; then
            shu.dep.Restore --no-check-cmddeps
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

    shu.cloneAndGetSubFolder(){ local url=$1; local path=$2; local branch=$3; local destinationPath="$4"
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

        shu.clone "$url" "$branch" "$tempDir"
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

    shu.clone(){ local url=$1; local branch=$2; local dest=$3
        if [ -d "$dest" ]; then
            _error="$ERROR_AREADY_DONE"
            return 1
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

    shu.getShuProjectRoot_absolute(){
        #look for a .shu folder in the current directory (director of script that called misc.Import). If not found, look in the parent, and so on
        local shuLocation="$(pwd)"
        while [ ! -d "$shuLocation/.shu" ] && [ "$shuLocation" != "/" ]; do
            shuLocation="$(dirname "$shuLocation")"
        done

        if [ ! -d "$shuLocation/.shu" ]; then
            _error="Could not find .shu folder in the current directory or any parent directory"
            _r=""
            return 1
        fi

        _r="$shuLocation"
        return 0
    }

    shu.dep.determine_Url_branch_folder_and_packageName(){ local url=$1; local destinationFolder=${2:-$(realpath -m "$(shu.getShuProjectRoot_absolute; echo "$_r")/.shu/packages")}; local ignoreAlreadyDoneError=${3:-false}
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

        #echo ""
        #echo "==============================="
        #echo "url: $url"
        #echo "branch: $branch"
        #echo "path: $path"
        #echo "packageName: $packageName"
        #echo "destinationFolder: $destinationFolder"
        #echo "==============================="

        _r=("$url" "$branch" "$path" "$packageName" "$destinationFolder")
        _r_url="${_r[0]}"
        _r_branch="${_r[1]}"
        _r_path="${_r[2]}"
        _r_packageName="${_r[3]}"
    }

    shu.dep.findIndexByPartialUrl(){ local url="$1"
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

    shu.dep.getUrlByIndex(){ local index="$1"

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

shu.depMain "$@"
return $?
