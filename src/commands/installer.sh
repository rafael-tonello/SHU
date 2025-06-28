#!/bin/bash
shu.installer.main(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.installer.Help
        return 0
    fi
    
    local func=$(echo "$1" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.installer.$func" "$@"
}

shu.installer.Help(){
    :;
}

shu.installer.Install(){ local url="$1"; shift
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

    cd "$HOME/.local/shu/installed"
    shu.Main psysdeps check
    #go back
    cd -
    if [ "$_error" != "" ]; then
        #yellow message
        printf "\033[0;33mWarning: Some commands necessary for the installed package was not found in the system. Command may not work as expected.\033[0m\n"
    fi

    #recusive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.Install "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi
    _error=""
    return 0
}

shu.installer.Uninstall(){ local packageOrCommandName="$1"; shift
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

    #recursive call to process remain arguments
    if [ "$#" -gt 0 ]; then
        shu.Uninstall "$@"
        if [ "$_error" != "" ]; then _error="Process aborted: $_error"; return 1; fi
        return $?
    fi

    _erro=""
    return 0
}

shu.installer.preinstallscripts.add(){
    :;
}

shu.installer.preinstallscripts.list(){
    :;
}

shu.installer.preinstallscripts.remove(){
    :;
}

shu.installer.postinstallscripts.add(){
    :;
}

shu.installer.postinstallscripts.list(){
    :;
}

shu.installer.postinstallscripts.remove(){
    :;
}

shu.installer.preuninstallscripts.add(){
    :;
}

shu.installer.preuninstallscripts.list(){
    :;
}

shu.installer.preuninstallscripts.remove(){
    :;
}



shu.installer.main "$@"
return $?
