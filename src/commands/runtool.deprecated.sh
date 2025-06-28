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

shu.Runtool.Help(){
    echo "  runtool <scriptName>   - Find scripts named <scriptName> in ./shu/packages/ and run them. Internally, it uses 'find' (in a recusive way) to find the desired script and, if it be able to find that, runs it."
}

if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help"  ]]; then
    shu.Runtool.Help
    return 0
fi

shu.Runtool "$@"
return $?
