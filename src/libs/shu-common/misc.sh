#!/bin/bash
#misc is basically a stdlib for shu.


#prevent double sourcing (and double parsing)
thisScriptLocation="$(realpath "${BASH_SOURCE[0]}")"

thisScriptLocation="${thisScriptLocation//[^a-zA-Z0-9]/}"
#declare a variable to check if the script was already loaded
declare -n SHU_MISC_LOADED="$thisScriptLocation"
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
    #   misc.Import "mySubpackage/file.sh --allow-subpackages" -> imports the file 'file.sh' in the subpackage 'mySubpackage' and all its subfolders (including .shu and its subfolders)
    misc.Import(){
        local callerScriptPath=$(dirname "${BASH_SOURCE[1]}")
        
        if [ "$#" -lt 1 ]; then
            _error="packageName was not informed"
            return 1
        fi

        #start search starting from the directory of the script that called this function. It allow the packages to find files int its own .shu folders
        misc.getShuProjectRoot "$(dirname "$(realpath "${BASH_SOURCE[1]}")")"; local shuProjectFolder="$_r"

        if [ "$_error" != "" ]; then
            _error="Could not find .shu folder: $_error"
            misc.printError "$_error"
            return 1
        fi

        local allowSubPackages=false
        if [[ "$1" == *"--allow-subpackages"* ]] || [[ "$1" == *"-asp"* ]]; then
            allowSubPackages=true
            #remove the --allow-subpackages or -asp from the arguments
            set -- "${@/--allow-subpackages/}"
            set -- "${@/-asp/}"
        fi

        filePaths=();
        for arg in "${@}"; do
            #if arg begins with '-', skip
            if [[ "$arg" == -* ]]; then
                continue;
            fi

            #if arg ends with .sh
            if [[ "$arg" == *.sh ]]; then
                #just import the file
                if [ -f "$shuProjectFolder/.shu/$arg" ]; then
                    filePaths+=("$shuProjectFolder/.shu/$arg")
                elif [ -f "$(pwd)/$arg" ]; then
                    filePaths+=("$(pwd)/$arg")
                else
                    local found=false;
                    if allowSubPackages; then
                        misc.import.tryFindInSubPackages "$filePath"; filePath="$_r"
                        if [ "$_error" == "" ]; then
                            found=true;
                            filePaths+=("$filePath")
                        fi
                    fi

                    if ! $found; then
                        #fullpath? file will be verified later
                        if [[ "$arg" != *.sh ]]; then
                            arg="$arg.sh"
                        fi

                        filePaths+=("$arg")
                    fi
                fi

            #else, if args ends with /***/ or ends with /** and allowSubPackages is true (/** and allowSubPackages is true is same of ends with /***)
            elif [[ "$arg" == */*** ]] || [[ "$arg" == */**  && "$allowSubPackages" == "true" ]]; then
                #recursive import scripts (including .shu folders)
                misc.findFiles "$shuProjectFolder/.shu/packages/$arg" true false
                if [ "$_error" != "" ]; then
                    _error="Could not find package '$arg': $_error"
                    misc.printError "$_error"
                    return 1
                fi

                filePaths+=("${_r[@]}")

            #else, if args ends with /**
            elif [[ "$arg" == */** ]]; then
                arg="${arg%/***}"
                #recursive import scripts (ignore .shu folders)
                misc.findFiles "$shuProjectFolder/.shu/packages/$arg" true true
                if [ "$_error" != "" ]; then
                    _error="Could not find package '$arg': $_error"
                    misc.printError "$_error"
                    return 1
                fi

                filePaths+=("${_r[@]}")
            
            
            
            else
                #import all scripts in the root of informed folder
                
                misc.findFiles "$shuProjectFolder/.shu/packages/$arg" false false
                if [ "$_error" != "" ]; then
                    _error="Could not find package '$arg': $_error"
                    misc.printError "$_error"
                    return 1
                fi

                filePaths+=("${_r[@]}")
            fi
        done

        #source all files in the filePaths array
        for filePath in "${filePaths[@]}"; do
            #if the filePath does not start with a slash, add the .shu folder path
            if [[ "$filePath" != /* ]]; then
                filePath="$shuProjectFolder/.shu/packages/$filePath"
            fi

            #if the file exists, source it
            if [ -f "$filePath" ]; then
                export SHU_IS_IMPORTING=true
                source "$filePath" "shuiissourcing"
                export SHU_IS_IMPORTING=false
            else
                #if --alow-subpackages or -asp is set
                # if [[ "$filePath" == *"--allow-subpackages"* ]] || [[ "$filePath" == *"-asp"* ]]; then
                #     #do not print error, just skip
                #     misc.import.tryFindInSubPackages "$filePath"; local retCode=$?; filePath="$_r"
                #     if [ "$retCode" -ne 0 ]; then
                #         _error="Could not find file '$filePath' in subpackages: $_error"
                #         misc.printError "$_error"
                #         return 1
                #     fi

                #     export SHU_IS_IMPORTING=true
                #     source "$filePath" "shuiissourcing"
                #     export SHU_IS_IMPORTING=false
                # fi
                _error="File $filePath does not exist"
                #check if file path contains '.shu'
                if [[ "$filePath" == *".shu"* ]]; then
                    _error="file $filePath does not exist. Did you run 'shu restore' after cloning the project?"
                else
                    _error="file $filePath was not found"
                fi

                misc.printError "$_error"
                return 1
            fi
        done
    }
    Import(){ misc.Import "$@"; }
    import(){ misc.Import "$@"; }

    misc.getShuProjectRoot(){ local startSearchLocation="$1"

        local shuLocation="$startSearchLocation"
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
        _error=""
        _r="obj_$((__o_count++))_"
        eval "$_r=obj"
        if [ ! -z "$_className" ]; then
            o.Set "$_r" "ClassName" "$_className"
        fi
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
            if [ "$arg" == "" ]; then
                continue;
            fi
            
            if [ -z "$obj" ]; then
                obj="$arg"
            else
                obj="$obj.$arg"
            fi
        done

        local okey=""
        if [[ "$obj" == *.* ]]; then
            local lastDotIndex="${obj##*.}"
            #separate the object name from the key (uses lastDotIndex)
            okey="${obj##*.}"
            obj="${obj%.*}"
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

            o._get "$currObjectName" "$childName"; local childObj="$_r"
            if [ ! -z "$_error" ]; then
                _error="Could not get child object '$childName' from object '$obj': $_error"
                return 1
            fi

            local searchKey="$childObj."
            if [ -n "$remainName" ]; then
                searchKey+="$remainName."
            fi
            searchKey+="$okey"

            o.resolveFinalObjectAndKey "$searchKey"; _r="$_r"
            return $?
        fi

        _r="$obj"
        _r_key="$okey"
        _error=""
        return 0
    }

    o.Set(){ local obj="$1"; local okey="$2"; local value="${3:-}"
        #if object name contains '.'
        if [[ "$obj" == *.* ]]; then
            value="$okey"
            #separate object and key by '.'
            local lastDotIndex="${obj##*.}"
            #separate the object name from the key (uses lastDotIndex)
            okey="${obj##*.}"
            obj="${obj%.*}"

            shift 1
        else
            shift 2
        fi

        o.resolveFinalObjectAndKey "$obj" "$okey"; local obj="$_r"; local okey="$_r_key"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj""_""$okey"

        #if there more than one argument
        if [ "$#" -gt 1 ]; then
            #if it is an array, set the array
            var=("$@")
        elif [ "$#" -eq 1 ]; then
            #if it is a single value, set the value
            var="$value"
        fi
    }

    o.Get(){ local obj="$1"; local okey="$2"
        #chec if key contains '.'
        o.resolveFinalObjectAndKey "$obj" "$okey"; local obj="$_r"; local okey="$_r_key"
        o._get "$obj" "$okey"; local retCode=$?
        return $retCode
    }

    o._get(){ local obj="$1"; local okey="$2"
        if [ -z "$obj" ] || [ -z "$okey" ]; then
            _error="Object or key was not informed"
            return 1
        fi

        declare -n var="$obj""_""$okey"

        #check if array size if greater than 1
        #if [ "${#var[@]}" -gt 1 ]; then
        #check if #var is an array
        if declare -p var &>/dev/null && [[ "$(declare -p var)" == *"declare -a"* ]]; then
            #if it is an array, return the array
            _r=("${var[@]}")
        else
            _r="${var[0]}"
        fi
    }

    o.Has(){ local obj="$1"; local okey="$2"
        o.resolveFinalObjectAndKey "$obj" "$okey"; local obj="$_r"; local okey="$_r_key"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        declare -n var="$obj""_""$okey"
        if [ -n "$var" ]; then
            _r=true
            return 0
        else
            _r=false
            return 1
        fi
    }

    o.HasMethod (){ local obj="$1"; local method="$2"
        o.resolveFinalObjectAndKey "$obj" "InvalidKey"; local obj="$_r"; local okey="$_r_key"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        o.IsObject "$obj"
        if [ ! -z "$_error" ]; then
            _error="Object '$obj' is not a valid object"
            return 1
        fi

        o.Get "$obj" "ClassName"; local className="$_r"
        if [ ! -z "$_error" ]; then
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

    o.Delete(){ local obj="$1"; local okey="$2"
        o.resolveFinalObjectAndKey "$obj" "$okey"; local obj="$_r"; local okey="$_r_key"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            _r=false
            return 1
        fi

        declare -n var="$obj""_""$okey"
        unset var
        _r=true
        return 0
    }

    o.ListProps(){ local obj="$1"
        if [ -z "$obj" ]; then
            _error="Object was not informed"
            return 1
        fi

        o.resolveFinalObjectAndKey "$obj" "InvalidProp"; local obj="$_r"; local okey="$_r_key"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        _r=()
        
        #get all variables that start with the object name
        for var in $(compgen -v | grep "^$obj"); do
            #remove the object name from the variable name
            var="${var#$obj""_}"

            #when a object is created, a property with the name of the object is created, so we need to skip it
            if [ "$var" == "$obj" ]; then
                continue; #skip the object name itself
            fi

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
        
        o.resolveFinalObjectAndKey "$obj" "ClassName"; local obj="$_r"
        if [ ! -z "$_error" ]; then
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
        #check if obj contains '.'
        local shiftNum=2
        if [[ "$obj" == *.* ]]; then
            shiftNum=1
            method=""
        fi

        o.resolveFinalObjectAndKey "$obj" "$method"
        local retCode=$?; 
        local obj="$_r";
        local method="$_r_key"



        shift $shiftNum

        if [ "$retCode" -ne 0 ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        if [ -z "$obj" ] || [ -z "$method" ]; then
            _error="Object or method was not informed"
            return 1
        fi

        o.IsObject "$obj"
        if [ ! -z "$_error" ]; then
            _error="Object '$obj' is not a valid object"
            return 1
        fi

        o.Get "$obj" "ClassName"; local className="$_r"
        if [ ! -z "$_error" ]; then
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

        o.resolveFinalObjectAndKey "$obj" "InvalidKey"; local obj="$_r"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        o.IsObject "$obj"
        if [ ! -z "$_error" ]; then
            _error="Object '$obj' is not a valid object"
            return 1
        fi

        #check if the object has the interface methods
        local className="$(o.Get "$obj" "ClassName")"
        if [ ! -z "$_error" ]; then
            _error="This is an anonymous object. Could not get class name of object '$obj': $_error"
            return 1
        fi

        #list all methods of the interface (functions started with $interface.)
        local interfaceMethods=$(declare -F | grep "^declare -f $interface\." | awk '{print $3}')
        
        #check if the object has the interface methods
        _error=""
        for method in $interfaceMethods; do
            #remove the class name from the method name
            method="${method#"$interface."}"
            #check if the method exists in the object
            if ! o.HasMethod "$obj" "$method"; then
                _error+="Method '$method' is missing. "
            fi
        done

        if [ "$_error" != "" ]; then
            _error="class '$className' (instance '$obj') does not implement interface '$interface': $_error"
            return 1
        fi

        _r=true
        _error=""
        return 0
    }

    o.Serialize(){ local obj="$1"; local serializer="$2"
        o.Implements "$obj" "ISerializer"
        if [ ! -z "$_error" ]; then
            _error="Object '$obj' does not implement ISerializer interface: $_error"
            return 1
        fi

        o._serialize "$obj" "$serializer"; local serializedData="$_r"
        return $?
    }
    o.ToString(){ o.Serialize "$@"; }

    o.Deserialize(){ local obj="$1"; local serializer="$2"; local _parent="${3:-}"
        #keys can have Object Notation, like 'obj.key' or 'obj.other.key'
        serializer.List; local keys=("${_r[@]}")
        if [ ! -z "$_error" ]; then
            _error="Could not list keys of serializer '$serializer': $_error"
            return 1
        fi

        for okey in "${keys[@]}"; do
            serializer.Get "$okey"; local value="$_r"
            if [ ! -z "$_error" ]; then
                _error="Could not get value of key '$okey' from serializer '$serializer': $_error"
                return 1
            fi

            o._deserializeProp "$obj" "$okey" "$value"
            if [ ! -z "$_error" ]; then
                _error="Could not deserialize key '$okey' in object '$obj': $_error"
                return 1
            fi
        done

        return 0
    }
    o.FromString(){ o.Deserialize "$@"; return $?; }

    o._serialize(){ local obj="$1"; local serializer="$2"; local _parent="${3:-}"
        o.ListProps "$obj"; local props=("${_r[@]}")
        if [ ! -z "$_error" ]; then
            _error="Could not list properties of object '$obj': $_error"
            return 1
        fi

        for prop in "${props[@]}"; do
            #if the property is an object, serialize it recursively
            if o.IsObject "$obj.$prop"; then
                o._serialize "$obj.$prop" "$serializer" "$_parent$prop."
            else
                #set the property in the serializer
                o.Get "$obj" "$prop"; local value="$_r"
                if [ ! -z "$_error" ]; then
                    _error="Could not get property '$prop' from object '$obj': $_error"
                    return 1
                fi

                #set the value in the serializer
                $serializer.Set "$_parent$prop" "$value"
            fi
        done

        o.Call "$serializer.Serialize"
        if [ ! -z "$_error" ]; then
            _error="Could not serialize object '$obj' to serializer '$serializer': $_error"
            return 1
        fi

        _error=""
        return 0
    }

    #ONKey comes from ObjectNotationKey
    o._deserializeProp(){ local obj="$1"; local ONKey="$2"; local value="$3";
        #ONKey can be like 'obj.key' or 'obj.other.key'
        #if ONKey contains '.', then it is a nested key
        if [[ "$ONKey" == *.* ]]; then
            local objecKey="${ONKey%%.*}"
            local remainKey="${ONKey#*.}"

            if ! o.Has "$obj" "$objecKey"; then
                o.New; local childObj="$_r"
                o.Set "$obj" "$objecKey" "$childObj"
            fi

            o.Get "$obj" "$objecKey"; local childObj="$_r"

            o._deserializeProp "$childObj" "$remainKey" "$value"
            local retCode=$?
            if [ "$_error" != "" ]; then
                _error="Could not deserialize key '$ONKey' in object '$obj': $_error"
                return 1
            fi
            return $?
        else
            #if ONKey does not contain '.', then it is a simple key
            o.Set "$obj" "$ONKey" "$value"
            return $?
        fi
    }
#}

#Common interfaces {
    #ISerializer {
        #set <key> <value>
        #Set a key-value pair in the serializer
        #Key can come using Object Notation, like 'obj.key' or 'obj.other.key'
        ISerializer.Set(){ _error="Not implemented"; return 1; }

        #get <key>
        #Returns the value of the key from the serializer
        #_r will should contain the value
        ISerializer.Get(){ _error="Not implemented"; return 1; }

        #List
        #list all keys in the serializer
        #returned keys can have Object Notation, like 'obj.key' or 'obj.other.key'
        #_r will should contain an array of keys
        #return 0 if list successfully, 1 if error
        ISerializer.List(){ _error="Not implemented"; return 1; }

        #serialize
        #Serialize the hold data to a string
        #_r will should contain the serialized data
        ISerializer.Serialize(){ _error="Not implemented"; return 1; }


        #deserialize <data>
        #Decode the data from a string and update the serializer
        ISerializer.Deserialize(){ _error="Not implemented"; return 1; }

        #NewInstance <currentObject>
        #Create a new serializer.
        #ISerializer.NewInstance(){ _error="Not implemented"; return 1; }
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
        IConnection.IsConnected(){ _error="Not implemented"; return 1; }

        #Read
        #Read the data from the connection.
        #_r will should contain the read data
        #_error should contain the error message if any
        #return 0 if read successfully, 1 if error
        IConnection.Read(){ _error="Not implemented"; return 1; }

        #Write<data>
        #write the data (string).
        #_r will should contain the number of bytes written
        #_error should contain the error message if any
        #return 0 if write successfully, 1 if error
        IConnection.Write(){ _error="Not implemented"; return 1; }

        #Disconnect (It should be a responsability of who implements the interface, and is not mandatory)
        #Disconnect the connection.
        #_r should return with true if closed successfully, false if error
        #_error should contain the error message if any
        #return 0 if closed successfully, 1 if error
        #IConnection.Disconnect(){ _error="Not implemented"; return 1; }

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

    #IWorkable is a class of works that needs to have its 'WorkStep' method called externally. These works
    #do not have the hability to run by themselves.
    #You can call the 'WorkStep' method directly (in a loop, for example) or, if you are using a Scheduler instance,
    #use the method 'Scheduler.RunWorkable' to run the work.
    #IWorkable {
        #Run
        #Run the worker
        #_r should return with true if run successfully, false if error
        #_error should contain the error message if any
        #return 0 if run successfully, 1 if error
        IWorker.WorkStep(){ _error="Not implemented"; return 1; }
    #}

    #IWorker is a class of works that can run by themselves, like a thread.
    #This class is hight dependent of Schedule library (shu/src/libs/shu-common/scheduler).
    #IWorkder{
        #Receives a 'Scheduler' object to be able to schedule its work.
        IWorkder.Init(){ _error="Not implemented"; return 1; }
    #}


#}

#return _r with a text that can be printed to the console. The line length is 
#defined by tput cols, or 80 if tput is not available.
#_print ($2) can be used to control if the line should be printed or not. The
#default behavior is to print the line (_print = true).
misc.CreateHorizontalLine(){ local _char="${1:-"-"}"; local _print="${2:-true}"
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

#allow to use optional pattern in shellscript.
#  1) Optional function should return a command call (to a function) in the format 'optfunc_<remainFuncName> arg1 arg2 ...'
#  2) During the parsing, the functin 'optfunc_<remainFuncName>' will be called with the logObject as the last argument.
#  3) If you pass an argument that begins with '--with-<aFunctionName>', the function 'aFunctionName' will be called, and
#    this function (aFunctionName) should return a command call in the format 'optfunc_<remainFuncName> arg1 arg2 ...' (as 
#    described in '1)'. All argumenter until next one that begins with '--' will be passed to the function
#  4) the functions 'optfunc_<remainFuncName>' should set properties in the object receiveid as the last argument, setting
#     up it.
#  5) If you use --with-<something>, and the function <something> does not exist, the property <something> can be set
#    in the object with the value of the next argument if you use '--allow-prop-set' or '-aps' as any of the arguments (the 
#    arumgnet '--allow-prop-set' or '-aps' is removed from the argument list before parsing of optionals). If you do not
#    use '--allow-prop-set' or '-aps', an error is printed and the parsing is aborted if the function <something> does not exist.
#
# #Example1:
#       withFile(){ local fName="$1"; local maxSizeBytes="$2"; 
#           optfunc_withFile_func(){ local fName="$1"; local maxSizeBytes="$2"; local obj="$3";
#               #create a file driver
#               o.Set "$obj.fName" "$fName"
#               o.Set "$obj.maxSizeBytes" "$maxSizeBytes"
#           }
#       
#           #should return a function call that starts with 'optfunc_'
#           _r="optfunc_withFile_func \"$fName\" \"$maxSizeBytes\""
#       }
#       
#       myFunction(){
#           o.New; local obj="$_r"
#           misc.parseOptionals "$obj" "$@"; local retCode=$?
#           echo "fileName: $(o.Get "$obj" "fileName")"
#       }
#
#       #call the function 'withFile' option  
#       myFunction --with-withFile "myfile.txt" 1024
#   
#       #also call 'withFile', because 'misc.parseOptionals' will try to find 'file' function using 'with' prefix (and capitalizing the first letter)
#       myFunction --with-file "myfile.txt" --with-maxSizeBytes 1024
#
# #example2:
#   myFunction(){
#       o.New; local obj="$_r"
#       misc.parseOptionals "$obj" "$@"; local retCode=$?
#       echo "fileName: $(o.Get "$obj" "fileName")"
#   }
#   myFunction --allow-prop-set --with-fName "myfile.txt" --with-maxSizeBytes 1024
misc.parseOptionals(){
    local obj="$1"; shift
    local i=0
    local allowPropSet=false
    if [[ "$1" == *"--allow-prop-set"* ]] || [[ "$1" == *"-aps"* ]]; then
        allowPropSet=true
        #remove the --allow-prop-set or -aps from the arguments
        set -- "${@/--allow-prop-set/}"
        set -- "${@/-aps/}"
    fi
    while true; do
        local arg="${!i}"; ((i++))
        if [[ -z "$arg" ]]; then
            break
        fi

        #check if argument begins with "--with-"
        if [[ "$arg" == --with-* ]]; then
            #remove "--with-" from the argument
            arg=${arg:7}

            #function can or not start with 'with'.
            #try to find 
            local funcName="$arg"

            if ! declare -f "$funcName" > /dev/null; then
                #try find with 'with' prefix (and first letter capitalized)
                
                #capitalize the first letter of the argument
                arg="${arg^}"
                funcName="with$arg"
            fi
            
            #check if the function exists
            if declare -f "$funcName" > /dev/null; then

                local funcArgs=();
                while true; do
                    local nextArg="${!i}";
                    if [[ "$nextArg" == --* ]] || [[ -z "$nextArg" ]]; then
                        break;
                    fi
                    funcArgs+=("$nextArg")
                    ((i++))
                done

                #call the function with the obj as argument
                eval "$funcName  \"${funcArgs[@]}\""
                local theOptionalFunc="$_r"
                eval "$theOptionalFunc \"$obj\""
            else
                if  ! $allowPropSet; then
                    _error="Function '$funcName' not found. Did you forget to implement it?"
                    misc.printError "$_error"
                    return 1
                fi
                #just set the property $arg in the object with the value of the next argument
                o.Set "$obj" "$arg" "${!i}"
                ((i++))
            fi
            #check if argument begin with "optfunc_"
        elif [[ "$arg" == optfunc_* ]]; then
            eval "$arg \"$obj\""
        elif [[ "$arg" == --* ]]; then
            local key=""
            local value=""
            #remove "--" from the argument
            arg=${arg:2}
            #check if $arg contains ':' or  '='
            if [[ "$arg" == *":"* ]] || [[ "$arg" == *"="* ]]; then
                #split the argument by ':' or '='
                key="${arg%%:*}"; key="${key%%=*}"
                value="${arg#*:}"; value="${value#*=}"
            else
                #value is in the next agument
                key="$arg"
                value="${!i}"; ((i++))
            fi

            o.Set "$obj" "$key" "$value"
        fi
    done
}


misc.parseOptions(){

}