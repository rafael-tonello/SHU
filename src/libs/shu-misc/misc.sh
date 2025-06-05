#!/bin/bash

#prevent double sourcing (and double parsing)
thisScriptLocation="$(realpath "${BASH_SOURCE[0]}")"
#get only validchars from thisScriptLocation
validChars='[a-zA-Z0-9_\-\/\.]'
thisScriptLocation="${thisScriptLocation//[^$validChars]/}"
declare -n SHU_MISC_LOADED="$(thisScriptLocation)"
if [ "$SHU_MISC_LOADED" == "true" ]; then
    return 0
fi
SHU_MISC_LOADED=true

#import mechanism to import scripts from packages {
    #Looks for scripts in ./shu/packages/[packageName]/[scriptName].sh and sources them.
    #scripts should be infomed in the format '<packageName>/<scriptName>'
    #you can inform scripts inside folders in the package, like '<packageName>/<folderName>/<scriptName>'
    #if only <packageName> all scripts in the package will be imported
    #
    #you can informe absolute paths like '/opt/shu/packages/<packageName>/<scriptName>.sh'
    #
    #Examples:
    #   misc.Import "myPackage" -> imports all scripts in the root of package 'myPackage' (include s all scripts in subfolders - but not .shu and .shu subfolders)
    #   misc.Import "myPackage/myScript.sh" -> imports the script 'myScript.sh' in the package 'myPackage'
    #   misc.Import "/opt/shu/packages/myPackage/myScript.sh" -> imports the script 'myScript.sh' in the package 'myPackage' in the path '/opt/shu/packages'
    #   misc.Import "myPackage1" "myPackage2" -> imports all scripts in the root of packages 'myPackage1' and 'myPackage2'
    #   misc.Import "myPackage1/myScript1.sh" "myPackage2/myScript2.sh" -> imports the scripts 'myScript1.sh' in the package 'myPackage1' and 'myScript2.sh' in the package 'myPackage2'
    #   misc.Import "myPackage1" "myPackage2/myScript2.sh" -> imports all scripts in the package 'myPackage1' and the script 'myScript2.sh' in the package 'myPackage2'
    #   misc.Import "myPackage1/**" -> imports all scripts in the package 'myPackage1' and all its subfolders (but not .shu and its subfolders)
    #   misc.Import "myPackage1/***" -> imports all scripts in the package 'myPackage1' and all its subfolders (including .shu and its subfolders)
    misc.Import(){
        if [ "$#" -lt 1 ]; then
            _error="packageName was not informed"
            return 1
        fi

        misc.getShuProjectRoot; local shuProjectFolder="$_r"
        if [ "$_error" != "" ]; then
            _error="Could not find .shu folder: $_error"
            return 1
        fi

        filePaths=();
        for arg in "${@}"; do
            #if arg ends with .sh
            if [[ "$arg" == *.sh ]]; then
                #just import the file
                filePaths+=("$arg")
            #else, if args ends with /**
            elif [[ "$arg" == */** ]]; then
                arg="${arg%/***}"
                #recursive import scripts (ignore .shu folders)
                misc.findFiles "$shuProjectFolder/.shu/packages/$arg" true true
                if [ "$_error" != "" ]; then
                    _error="Could not find package '$arg': $_error"
                    return 1
                fi

                filePaths+=("${_r[@]}")
            
            #else, if args ends with /***/
            elif [[ "$arg" == */*** ]]; then
                #recursive import scripts (including .shu folders)
                misc.findFiles "$shuProjectFolder/.shu/packages/$arg" true false
                if [ "$_error" != "" ]; then
                    _error="Could not find package '$arg': $_error"
                    return 1
                fi

                filePaths+=("${_r[@]}")
            
            else
                #import all scripts in the root of informed folder
                misc.findFiles "$shuProjectFolder/.shu/packages/$arg" false false
                if [ "$_error" != "" ]; then
                    _error="Could not find package '$arg': $_error"
                    return 1
                fi

                filePaths+=("${_r[@]}")
            fi
        fi

        #source all files in the filePaths array
        for filePath in "${filePaths[@]}"; do
            #if the filePath does not start with a slash, add the .shu folder path
            if [[ "$filePath" != /* ]]; then
                filePath="$shuLocation/.shu/packages/$filePath.sh"
            fi

            #if the file exists, source it
            if [ -f "$filePath" ]; then
                export SHU_IS_IMPORTING=true
                source "$filePath" "shuiissourcing"
                export SHU_IS_IMPORTING=false
            else
                _error="File $filePath does not exist"
                return 1
            fi
        done
    }
    Import(){ misc.Import "$@"; }
    import(){ misc.Import "$@"; }

    misc.getShuProjectRoot(){
        #look for a .shu folder in the current directory (director of script that called misc.Import). If not found, look in the parent, and so on
        local shuLocation="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
        while [ ! -d "$shuLocation/.shu" ] && [ "$shuLocation" != "/" ]; do
            shuLocation="$(dirname "$shuLocation")"
        done

        if [ ! -d "$shuLocation/.shu" ]; then
            _error="Could not find .shu folder in the current directory or any parent directory"
            return 1
        fi

        _r="$shuLocation"
        return 0
    }

    misc.findFiles(){ local path="$1"; local recursive="${2:-false}"; local ignoreShuFolders="${3:-true}"
        if [ ! -d "$path" ]; then
            _error="Path '$path' is not a directory"
            return 1
        fi

        local files=()
        #get all files in the folder
        for item in "$path"/*; do
            #check if is a file and if it is a script
            if [ -f "$item" ] && [[ "$item" == *.sh ]]; then
                files+=("$(realpath "$item")")
            #check if is a folder (but not .shu)
            elif [ -d "$item" ] && [[ "$(basename "$item")" != ".shu" ]] || [ "$ignoreShuFolders" == false ]; then
                #if is a folder, call the function recursively
                misc.findFiles "$item" "$recursive" "$ignoreShuFolders"; local subFiles=("${_r[@]}")
                files+=("${subFiles[@]}")
            fi
        done

        _r=("${files[@]}")
        return 0
    }

    misc.isShuImporting(){
        _r=$SHU_IS_IMPORTING
        #check if the variable SHU_IS_IMPORTING is set and true
        if [ "$SHU_IS_IMPORTING" == "true" ]; then
            return 0
        else
            return 1
        fi
    }
    shu.isImporting(){ misc.isShuImporting; return $?; }
    isShuImporting(){ misc.isShuImporting; return $?; }
#}

#basic object/stuct operations (allow basic OO oiperations in bash){

    __o_count=0
    o.New(){ local _className="$1"
        _r="obj_$((__o_count++))_"
        eval "$_r=obj"
        o.Set "$_r" "ClassName" "$_className"
    }


    #resolve the last object name. Key could be informed with obj.<key> or via 'key' argument
    #examples:
    #   o.resolveFinalObjectAndKey "obj" "key" -> returns "name of obj" and "key"
    #   o.resolveFinalObjectAndKey "obj.key" -> returns "name obj" and "key"
    #   o.resolveFinalObjectAndKey "obj.other.childobject" "key" -> returns name of child object and "key"
    #   o.resolveFinalObjectAndKey "obj" "other.childobject.key" -> returns name of child object and "key"
    o.resolveFinalObjectAndKey(){
        local obj=""
        #concatenate all args using '.'
        for arg in "$@"; do
            if [ -z "$obj" ]; then
                obj="$arg"
            else
                obj="$obj.$arg"
            fi
        done

        local key=""
        if [[ "$obj" == *.* ]]; then
            local lastDotIndex="${obj##*.}"
            #separate the object name from the key (uses lastDotIndex)
            obj="${obj%.*}"
            key="${obj##*.}"
        else
            _error="Key was not informed"
            return 1
        fi

        if [[ "$obj" == *.* ]]; then
            local currObjectName="${obj%%.*}"
            local childName="${obj#*.}"
            local remainName=""
            if [[ "$childName" == *.* ]]; then
                childName="${obj%%.*}"
                remainName="${obj#*.}"
            fi

            #here, we have currObjectName, childName and remainName separated from object
            #if obj, for example, is 'obj.child.other.child.names', then: 
            #   currObjectName='obj', childName='child', remainName='other.child.names'
            #if obj contains only 'obj.child', then:
            #   currObjectName='obj', childName='child', remainName=''

            o._get "$currentObjectName" "$childName"; local childObj="$_r"
            if [ "$?" -ne 0 ]; then
                _error="Could not get child object '$childName' from object '$obj': $_error"
                return 1
            fi

            local searchKey="$childObject."
            if [ -n "$remainName" ]; then
                searchKey+="$remainName."
            fi
            searchKey+="$key"

            o.resolveFinalObjectAndKey "$searchKey"; _r="$_r"
            return $?
        fi

        _r="$obj"
        _r_key="$key"
        return 0
    }

    o.Set(){ local obj="$1"; local key="$2"; local value="$3"
        o.resolveFinalObjectAndKey "$obj" "$key"; local obj="$_r"; local key="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj.$key"
        var="$value"
    }

    o.Get(){ local obj="$1"; local key="$2"

        #chec if key contains '.'
        o.resolveFinalObjectAndKey "$obj" "$key"; local obj="$_r"; local key="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj.$key"
        _r="$var"
    }

    o._get(){ local obj="$1"; local key="$2"
        if [ -z "$obj" ] || [ -z "$key" ]; then
            _error="Object or key was not informed"
            return 1
        fi

        declare -n var="$obj.$key"
        _r="$var"
    }

    o.Has(){ local obj="$1"; local key="$2"
        o.resolveFinalObjectAndKey "$obj" "$key"; local obj="$_r"; local key="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj.$key"
        if [ -n "$var" ]; then
            _r=true
            return 0
        else
            _r=false
            return 1
        fi
    }

    o.HasMethod (){ local obj="$1"; local method="$2"
        o.resolveFinalObjectAndKey "$obj" "$key"; local obj="$_r"; local key="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        o.IsObject "$obj"
        if [ "$?" -ne 0 ]; then
            _error="Object '$obj' is not a valid object"
            return 1
        fi

        o.Get "$obj" "ClassName"; local className="$_r"
        if [ "$?" -ne 0 ]; then
            _error="Could not get class name of object '$obj': $_error"
            return 1
        fi

        #check if the method exists in the class
        if declare -F "${className}.${method}" > /dev/null; then
            _r=true
            return 0
        else
            _r=false
            return 1
        fi
    }

    o.Delete(){ local obj="$1"; local key="$2"
        o.resolveFinalObjectAndKey "$obj" "$key"; local obj="$_r"; local key="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj.$key"
        unset var
    }

    o.ListProps(){ local obj="$1"
        if [ -z "$obj" ]; then
            _error="Object was not informed"
            return 1
        fi

        o.resolveFinalObjectAndKey "$obj" "$key"; local obj="$_r"; local key="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        _r=()
        #get all variables that start with the object name
        for var in $(compgen -v | grep "^$obj"); do
            _r+=("$var")
        done
    }

    o.Destroy(){ local obj="$1"; local _destroyChildren="${2:-false}"
        if [ -z "$obj" ]; then
            _error="Object was not informed"
            return 1
        fi

        o.ListProps "$obj"; local props=("${_r[@]}")
        for prop in "${props[@]}"; do
            #if the property is an object, destroy it
            if [ "$_destroyChildren" == "true" ]; then
                if o.IsObject "$prop"; then
                    o.Destroy "$prop" true
                fi
            fi

            o.Delete "$obj" "$prop"
        done
    }

    o.IsObject(){ local obj="$1"
        if [ -z "$obj" ]; then
            _error="Object was not informed"
            return 1
        fi
        
        o.resolveFinalObjectAndKey "$obj"; local obj="$_r"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj"
        if [ -n "$var" ]; then
            _r=true
            return 0
        else
            _r=false
            return 1
        fi
    }

    o.Call(){ local obj="$1"; local method="$2"; 
        o.resolveFinalObjectAndKey "$obj" "$method"; local obj="$_r"; local method="$_r_key"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        if [ -z "$obj" ] || [ -z "$method" ]; then
            _error="Object or method was not informed"
            return 1
        fi

        o.IsObject "$obj"
        if [ "$?" -ne 0 ]; then
            _error="Object '$obj' is not a valid object"
            return 1
        fi

        o.Get "$obj" "ClassName"; local className="$_r"
        if [ "$?" -ne 0 ]; then
            _error="This is an anonymous object. Could not get class name of object '$obj': $_error"
            return 1
        fi

        local finalMethodName="$className.$method"

        $finalMethodName "$obj" "$@"
        return $?
    }

    o.Implements(){ local obj="$1"; local interface="$2"
        _r=false
        if [ -z "$obj" ] || [ -z "$interface" ]; then
            _error="Object or interface was not informed"
            return 1
        fi

        o.resolveFinalObjectAndKey "$obj"; local obj="$_r"
        if [ "$?" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        o.IsObject "$obj"
        if [ "$?" -ne 0 ]; then
            _error="Object '$obj' is not a valid object"
            return 1
        fi

        #check if the object has the interface methods
        local className="$(o.Get "$obj" "ClassName")"
        if [ "$?" -ne 0 ]; then
            _error="This is an anonymous object. Could not get class name of object '$obj': $_error"
            return 1
        fi

        #check if the className has the interface methods
        local interfaceMethods=$(compgen -A function | grep "^$className\.$interface\.")
        
        #check if the object has the interface methods
        _error=""
        for method in $interfaceMethods; do
            #remove the class name from the method name
            method="${method#"$className."}"
            #check if the method exists in the object
            if ! o.HasMethod "$obj" "$method"; then
                _error+="Method '$method' is missing. "
            fi
        done

        if [ -n "$_error" ]; then
            _error="Object '$obj' does not implement interface '$interface': $_error"
            return 1
        fi

        _r=true
        return 0
    }
        
#}

#Common interfaces {
    #ISerializer {
        #set <key> <value>
        ISerializer.Set(){ _error="Not implemented"; return 1; }

        #get <key>
        #_r will should contain the value
        ISerializer.Get(){ _error="Not implemented"; return 1; }

        #serialize
        #Serialize the data to a string
        #_r will should contain the serialized data
        ISerializer.Serialize(){ _error="Not implemented"; return 1; }


        #deserialize <data>
        #Deserialize the data from a string
        ISerializer.Deserialize(){ _error="Not implemented"; return 1; }

        #ReadObject <obj>
        #Import all properties from the object to the serializer
        ISerializer.ReadObject(){ _error="Not implemented"; return 1; }

        #WriteObject <obj>
        #Export all properties from the serializer to the object
        ISerializer.WriteObject(){ _error="Not implemented"; return 1; }
    #}

    #IReadWriter {
        #Write <data>
        #Write the data to the destination
        #_error should contain the error message if any
        #return 0 if write successfully, 1 if error
        IReadWriter.Write(){ _error="Not implemented"; return 1; }

        #Read
        #Read the data from the string
        #_r will should contain the read data
        #_error should contain the error message if any
        #return 0 if read successfully, 1 if error
        IReadWriter.Read(){ _error="Not implemented"; return 1; }

        #CanRead
        #Check if the ReadWriter can read data
        #_r will should contain true or false
        #_error should contain the error message if any
        #return 0 if can read, 1 if cannot read
        IReadWriter.CanRead(){ _error="Not implemented"; return 1; }


        #CanWrite
        #Check if the ReadWriter can write data
        #_r will should contain true or false
        #_error should contain the error message if any
        #return 0 if can write, 1 if cannot write
        IReadWriter.CanWrite(){ _error="Not implemented"; return 1; }
    #}

    #IConnection {
        IConnection.Connected(){ _error="Not implemented"; return 1; }

        #Write<data>
        #write the data (string).
        #_r will should contain the number of bytes written
        #_error should contain the error message if any
        #return 0 if write successfully, 1 if error
        IConnection.Write(){ _error="Not implemented"; return 1; }

        #Read
        #Read the data from the connection.
        #_r will should contain the read data
        #_error should contain the error message if any
        #return 0 if read successfully, 1 if error
        IConnection.Read(){ _error="Not implemented"; return 1; }

        #Close
        #Close the connection.
        #_r should return with true if closed successfully, false if error
        #_error should contain the error message if any
        #return 0 if closed successfully, 1 if error
        IConnection.Close(){ _error="Not implemented"; return 1; }

        #Available
        #Returns the size of the data available to read.
        #_r will should contain the size of the data available to read
        #_error should contain the error message if any
        #return 0 if available successfully, 1 if error
        IConnection.Available(){ _error="Not implemented"; return 1; }

        #CanRead
        #Check if the connection can read data
        #_r will should contain true or false
        #return 0 if can read, 1 if cannot read
        IConnection.CanRead(){ _error="Not implemented"; return 1; }

        #CanWrite
        #Check if the connection can write data
        #_r will should contain true or false
        #return 0 if can write, 1 if cannot write
        IConnection.CanWrite(){ _error="Not implemented"; return 1; }
    #}
#}

#printing messages and errors {
    misc.printGreen(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;32m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printRed(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;31m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printYellow(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;33m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printBlue(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;34m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printCyan(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;36m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printMagenta(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;35m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printGray(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;90m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.printError(){
        local errorMessage="$1";
        local _allLinesPrefix="${2:-""}"; 
        local _beginLineText="${3:-"⤷"}"; 
        local _endLineText="${4:-""}"; 
        local _contextSeparator="${5:-":"}";

        currentPrefix="$_allLinesPrefix"
        local ret=""
        while [ "$errorMessage" != "" ]; do
            #fine next $_contextSeparator
            local errorPart=""
            if [[ "$errorMessage" == *"$_contextSeparator"* ]]; then
                #get the first part of the error message
                errorPart=$(echo "$errorMessage" | cut -d"$_contextSeparator" -f1)
                #get the rest of the error message
                errorMessage=$(echo "$errorMessage" | cut -d"$_contextSeparator" -f2-)
            else
                errorPart="$errorMessage"
                errorMessage=""
            fi
            if [ "$ret" != "" ]; then
                ret+="\n"
                ret+="$currentPrefix$_beginLineText$errorPart$_endLineText"
            else
                ret+="$currentPrefix$errorPart$_endLineText"
            fi
            currentPrefix+="  "
        done
        misc.printRed "$ret\n" > /dev/stderr
    }
#}
