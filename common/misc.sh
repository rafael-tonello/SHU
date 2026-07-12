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

#when a method that is being called by o.Call is not found, with SUPRESS_O_CALL_FROM_STACK_TRACING=true the 'o.Call' will be removed from stack trace, as it is not relevant for the error and just adds noise to the stack trace. If you want to print o.Call in the stack trace for some rason, just set SUPRESS_O_CALL_FROM_STACK_TRACING=false
SUPRESS_O_CALL_FROM_STACK_TRACING=true

#import mechanism {
    #looks for the filename and source it
    declare -A misc_loadedFiles=()

    misc__import_remain_files=()
    #loads many import in one call (if you use misc.Import "file1.sh" "file2.sh" ..., the folders will be
    #scrolled only once.)
    misc._import(){
        #last argument is the folder
        local rootPath="$1"
        
        local allFiles=("$rootPath"/*)
        local subfolders=()
        for file in "${allFiles[@]}"; do
            local realPath="$(realpath "$file")"
            if [ -f "$file" ]; then
                #check if $file meets one argument
                for filename in "${misc__import_remain_files[@]}"; do
                    local relativePath="${realPath#$PWD/}"
                    if [[ "$relativePath" == "$filename" ]] || [[ "$relativePath" == */"$filename" ]]; then
                        if [ "${misc_loadedFiles[$filename]}" != "loaded" ]; then
                            source "$realPath"
                            _error=""
                            _r="$realPath"
                            misc_loadedFiles["$realPath"]="loaded"
                        fi
                        #remove the filename from the list of arguments
                        misc__import_remain_files=("${misc__import_remain_files[@]/$filename}")

                        #check if there are remains files to be imported, if not, return
                        if [ "${#misc__import_remain_files[@]}" -eq 0 ]; then
                            return 0
                        fi

                        break
                    fi
                done

            elif [ -d "$file" ]; then
                subfolders+=("$file")
            fi
        done

        #if the file was not found in the current folder, search in the subfolders
        for folder in "${subfolders[@]}"; do
            if [ "${#misc__import_remain_files[@]}" -eq 0 ]; then
                return 0
            fi

            misc._import "$folder"
        done

    }

    #you can specify the root folder as first or last argument. The reamisn ones should be filenames
    #misc.Import "file1" [ "file2" ] [...] [folder] - imports the files from the folder (or current folder if not informed)
    #misc.Import [folder] "file1" [ "file2" ] [...] - imports the files from the folder (or current folder if not informed)
    misc.Import(){
        #check if last argument is a folder, if not, use current folder
        local lastArg="${@: -1}"
        if [ -d "$lastArg" ]; then
            misc__import_remain_files=("${@:1:$(($#-1))}")
            misc._import "$lastArg"
        else
            #check if first argument is a folder, if so, use it as root folder
            if [ -d "$1" ]; then
                misc__import_remain_files=("${@:2}")
                misc._import "$1"
            else
                misc__import_remain_files=("$@")
                misc._import "$PWD"
            fi
        fi
    };
    misc.Using() { misc.Import "$@"; }
    Using () { misc.Import "$@"; }
#}

#basic object/stuct operations (allow basic OO oiperations in bash){

    __o_count=0

    __o_SubshellRW=false
    __o_SubShellRWId=0

    #enable subshell read/write mode make subshells able to also write to the objects created in the parent shell and it is a powerfull way to enable a back-and-forth communication between subshells and the parent shell. It is reached by storing the object data in temporary files in the /dev/shm filesystem, which is a tmpfs (temporary file storage in memory) in Linux systems.
    o.EnableSubshellRW(){ 
        __o_SubshellRW=true;
        #processid + random 
        __o_SubShellRWId="$$_$RANDOM"
        mkdir -p "/dev/shm/shu_subshell_rw/$__o_SubShellRWId"
    }
    o.DisableSubshellRW(){ __o_SubshellRW=false; }

    o.New(){ local _className="$1"
        _error=""
        local tmp="obj_$((__o_count++))_"
        eval "$tmp=obj"
        if [ ! -z "$_className" ]; then
            o.Set "$tmp" "ClassName" "$_className"
        fi

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$tmp"
            echo "$tmp" > "$fname"
        fi

        _r="$tmp"
    }


    #resolve the last object name. Key could be informed with obj.<key> or via 'key' argument
    #examples:
    #   o.resolveFinalObjectAndKey "obj" "key" -> returns "name of obj" and "key"
    #   o.resolveFinalObjectAndKey "obj.key" -> returns "name obj" and "key"
    #   o.resolveFinalObjectAndKey "obj.other.childobject" "key" -> returns name of child object and "key"
    #   o.resolveFinalObjectAndKey "obj" "other.childobject.key" -> returns name of child object and "key"
    o_resolveFinalObjectAndKey_allow_creating=false
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
                local tmp="$childName"
                childName="${tmp%%.*}"
                remainName="${tmp#*.}"
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

            if  [ -z "$childObj" ]; then
                #create an anonimous object
                if ! $o_resolveFinalObjectAndKey_allow_creating; then
                    _error="Object '$currObjectName' does not have a child object '$childName' and creating objects is not allowed"
                    return 1
                fi
                o.New; childObj="$_r"
                o.Set "$currObjectName" "$childName" "$childObj"
                o_resolveFinalObjectAndKey_allow_creating=true
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
        o_resolveFinalObjectAndKey_allow_creating=false
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

        o_resolveFinalObjectAndKey_allow_creating=true
        o.resolveFinalObjectAndKey "$obj" "$okey"; local obj="$_r"; local okey="$_r_key"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$obj""_""$okey"
            rm -f "$fname" 2>/dev/null
            for arg in "$@"; do
                echo "$arg" >> "$fname"
            done
            return 0
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
        _error=""
        if [ -z "$obj" ] || [ -z "$okey" ]; then
            _error="Object or key was not informed"
            return 1
        fi

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$obj""_""$okey"
            if [ ! -f "$fname" ]; then
                _r=""
                return 1
            fi

            mapfile -t lines < "$fname"
            if [ "${#lines[@]}" -gt 1 ]; then
                _r=("${lines[@]}")
            else
                _r="${lines[0]}"
            fi

            return 0
        fi

        declare -n var="$obj""_""$okey"

        if [ ! -n "$var" ]; then
            _r=""
            return 1
        fi

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

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$obj""_""$okey"
            if [ -f "$fname" ]; then
                _r=true
                return 0
            else
                _r=false
                return 1
            fi
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

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$obj""_""$okey"
            rm -f "$fname" 2>/dev/null
            _r=true
            return 0
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

        if $__o_SubshellRW; then
            local path="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/"
            for file in "$path"*; do
                #get the filename without the path
                local filename="$(basename "$file")"
                #check if filename starts with obj_
                if [[ "$filename" == "$obj""_"* ]]; then
                    #remove the object name from the filename
                    local prop="${filename#"$obj""_"}"
                    _r+=("$prop")
                fi
            done

            return 0
        fi
        
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

        #call Destory method, if present
        o.HasMethod "$obj" "Destroy"; local hasDestroyMethod="$_r"
        if $hasDestroyMethod; then
            o.Call "$obj" "Destroy" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call Destroy method of object '$obj': $_error"
                return 1
            fi
        fi

        #destroy methos used specifically by classes created by o.NewAnon function
        o.HasMethod "$obj" "__Anonimous_Destroy"; local hasADestroyMethod="$_r"
        if $hasADestroyMethod; then
            o.Call "$obj" "__Anonimous_Destroy" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call __Anonimous_Destroy method of object '$obj': $_error"
                return 1
            fi
        fi

        #call OnDestroy method, if present
        o.HasMethod "$obj" "OnDestroy"; local hasDestroyMethod="$_r"
        if $hasDestroyMethod; then
            o.Call "$obj" "OnDestroy" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call OnDestroy method of object '$obj': $_error"
                return 1
            fi
        fi

        #call Finalize method, if present
        o.HasMethod "$obj" "Finalize"; local hasDestroyMethod="$_r"
        if $hasDestroyMethod; then
            o.Call "$obj" "Finalize" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call Finalize method of object '$obj': $_error"
                return 1
            fi
        fi

        #call OnDenFinalize method, if present
        o.HasMethod "$obj" "OnFinalize"; local hasDestroyMethod="$_r"
        if $hasDestroyMethod; then
            o.Call "$obj" "OnFinalize" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call OnFinalize method of object '$obj': $_error"
                return 1
            fi
        fi

        #call Finalize method, if present
        o.HasMethod "$obj" "Release"; local hasDestroyMethod="$_r"
        if $hasDestroyMethod; then
            o.Call "$obj" "Release" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call Release method of object '$obj': $_error"
                return 1
            fi
        fi

        #call OnDenFinalize method, if present
        o.HasMethod "$obj" "OnRelease"; local hasDestroyMethod="$_r"
        if $hasDestroyMethod; then
            o.Call "$obj" "OnRelease" "$_destroyChildren"
            if [ "$_error" != "" ]; then
                _error="Could not call OnRelease method of object '$obj': $_error"
                return 1
            fi
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

        #erase the object itself
        declare -n var="$obj"
        unset var

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$obj"
            rm -f "$fname" 2>/dev/null
        fi
        _r=""
        _error=""
        return 0
    }
    o.Release(){ o.Destroy "$@"; }
    #o.Finalize(){ o.Destroy "$@"; }
    #o.Free(){ o.Destroy "$@"; }

    o.IsObject(){ local obj="$1"
        if [ -z "$obj" ]; then
            _error="Object was not informed"
            return 1
        fi
        
        o.resolveFinalObjectAndKey "$obj" "InvalidKey"; local obj="$_r"
        if [ ! -z "$_error" ]; then
            _error="Could not get final object name: $_error"
            return 1
        fi

        if $__o_SubshellRW; then
            local fname="/dev/shm/shu_subshell_rw/$__o_SubShellRWId/$obj"
            if [ -f "$fname" ]; then
                _r=true
                return 0
            else
                _r=false
                return 1
            fi
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
            local tmpError="error calling "$obj.$method": could  not get final object name: $_error"
            misc.StackTraceToString '_f(){ local fName="$1"; local file="$2"; local line="$3"
                if [[ "$fName" != "o.Call" || "$SUPRESS_O_CALL_FROM_STACK_TRACING" == "false" ]]; then
                    _r=true
                else
                    _r=false
                fi

            }; _f'
            #the double ':' make the printError function prints one ':' after the 'Call stack' text
            _error="$tmpError. Call stack:: $_r"
            misc.PrintError "$_error"
            return 1
        fi

        if [ -z "$obj" ] || [ -z "$method" ]; then
            local tmpError="error calling "$obj.$method": object or method was not informed"
            misc.StackTraceToString '_f(){ local fName="$1"; local file="$2"; local line="$3"
                if [[ "$fName" != "o.Call" || "$SUPRESS_O_CALL_FROM_STACK_TRACING" == "false" ]]; then
                    _r=true
                else
                    _r=false
                fi

            }; _f'
            #the double ':' make the printError function prints one ':' after the 'Call stack' text
            _error="$tmpError. Call stack:: $_r"
            misc.PrintError "$_error"
            return 1
        fi

        o.IsObject "$obj"
        if [ ! -z "$_error" ]; then
            local tmpError="error calling "$obj.$method": object '$obj' is not a valid object"
            misc.StackTraceToString '_f(){ local fName="$1"; local file="$2"; local line="$3"
                if [[ "$fName" != "o.Call" || "$SUPRESS_O_CALL_FROM_STACK_TRACING" == "false" ]]; then
                    _r=true
                else
                    _r=false
                fi

            }; _f'
            #the double ':' make the printError function prints one ':' after the 'Call stack' text
            _error="$tmpError. Call stack:: $_r"
            misc.PrintError "$_error"
            return 1
        fi

        o.Get "$obj" "ClassName"; local className="$_r"
        if [ ! -z "$_error" ] || [ -z "$className" ]; then
            local tmpError="error calling "$obj.$method": error calling object '$obj' function"

            if [ ! -z "$_error" ]; then
                tmpError+=": $_error"
            #a more detailed error if $className is empty
            elif [ -z "$className" ]; then
                tmpError+=": object has no class name"

                #check if $obj begins with 'obj_' (it is the default prefix for objects created with o.New function)
                if [[ "$obj" != obj_* ]]; then
                    tmpError+=". Did you forget a '$' before the object name?"
                fi
            fi


            misc.StackTraceToString '_f(){ local fName="$1"; local file="$2"; local line="$3"
                if [[ "$fName" != "o.Call" || "$SUPRESS_O_CALL_FROM_STACK_TRACING" == "false" ]]; then
                    _r=true
                else
                    _r=false
                fi

            }; _f'
            #the double ':' make the printError function prints one ':' after the 'Call stack' text
            _error="$tmpError. Call stack:: $_r"

            misc.PrintError "$_error"
            return 1
        fi

        local finalMethodName="$className.$method"

        #check if the method exists in the class
        if ! declare -F "$finalMethodName" > /dev/null; then
            #the double ':' make the printError function prints one ':' after the 'Call stack' text
            local tmpError="error calling "$obj.$method": method '$method' does not exist in class '$className'. Call stack:: "
            #print call stack

            misc.StackTraceToString '_f(){ local fName="$1"; local file="$2"; local line="$3"
                if [[ "$fName" != "o.Call" || "$SUPRESS_O_CALL_FROM_STACK_TRACING" == "false" ]]; then
                    _r=true
                else
                    _r=false
                fi

            }; _f'
            
            _error+="$tmpError$_r"

            #this is a high level error, an should be printed with stack trace, even with _error return
            misc.PrintError "$_error"
            return 1
        fi

        $finalMethodName "$obj" "$@"
        return $?
    }

    #check if object/struct or class implements the interfaces
    #interfaces are informed as arguments after the object name, and can be more than one
    #Ex.: 
    #   o.Implements "obj" "Interface1" "Interface2"
    #   if !_r; then
    #       misc.PrintError "Object does not implement the interfaces: $_error"
    #   fi
    o.Implements(){ local objOrClassName="$1"; shift
        local interfaces=("$@")
        if [ -z "$objOrClassName" ] || [ ${#interfaces[@]} -eq 0 ]; then
            _error="Object or interface was not informed"
            _r=false
            return 1
        fi

        if [[ "$objOrClassName" == *.* ]]; then
            o.resolveFinalObjectAndKey "$objOrClassName" "InvalidKey"; local objOrClassName="$_r"
            if [ ! -z "$_error" ]; then
                _error="Could not get final object name: $_error"
                _r=false
                return 1
            fi
        fi


        local className="$objOrClassName"
        local isObject=false;

        if o.IsObject "$objOrClassName"; then
            isObject=true
            o.Get "$objOrClassName" "ClassName"; className="$_r"
            if [ ! -z "$_error" ]; then
                _error="This is an anonymous object. Could not get class name of object '$objOrClassName': $_error"
                _r=false
                return 1
            fi
        fi

        local missingInterfaces=""
        _error=""
        for interface in "${interfaces[@]}"; do

            #list all methods of the interface (functions started with $interface.)
            local interfaceMethods=$(declare -F | grep "^declare -f $interface\." | awk '{print $3}')

            if [ -z "$interfaceMethods" ]; then
                if [ "$_error" != "" ]; then
                    _error+=" + "
                fi
                _error="Interface '$interface' does not have any methods or does not exist"

                #check if missingInterfaces already contains the interface name
                if [[ "$missingInterfaces" != *"$interface"* ]]; then
                    if [ -n "$missingInterfaces" ]; then
                        missingInterfaces+=", "
                    fi
                    missingInterfaces+="$interface"
                fi
            fi
        
            #check if the object has the interface methods
            for method in $interfaceMethods; do
                #remove the class name from the method name
                method="${method#"$interface."}"
                
                local destinationMethodName="$className.$method"
                if ! declare -F "$destinationMethodName" > /dev/null; then
                    if [ "$_error" != "" ]; then
                        _error+=" + "
                    fi

                    #check if is multiple interface
                    if [ ${#interfaces[@]} -gt 1 ]; then
                        _error+="'$method' (interface '$interface') is missing in class '$className'"
                    else
                        _error+="method '$method' is missing in class '$className'"
                    fi

                    #check if missingInterfaces already contains the interface name
                    if [[ "$missingInterfaces" != *"$interface"* ]]; then
                        if [ -n "$missingInterfaces" ]; then
                            missingInterfaces+=", "
                        fi
                        missingInterfaces+="$interface"
                    fi
                fi
            done

        done

        if [ "$_error" != "" ]; then
            if [ ${#interfaces[@]} -gt 1 ]; then
                _error="class/struct '$className' does not implement interfaces '$missingInterfaces': $_error"
            else
                _error="class/struct '$className' does not implement interface '$missingInterfaces': $_error"
            fi
            _r=false
            return 1
        fi

        _r=true
        _error=""
        
        return 0
    }
    o.DoesImplement(){ o.Implements "$@"; return $?; }

    o.Serialize(){ local obj="$1"; local serializer="$2"
        o.Implements "$serializer" "ISerializer"
        if [ ! -z "$_error" ]; then
            _error="Object '$serializer' does not implement ISerializer interface: $_error"
            return 1
        fi

        o._serialize "$obj" "$serializer"; local serializedData="$_r"
        return $?
    }
    o.ToString(){ o.Serialize "$@"; }

    #if you pass "obj" as "", a new one will be created
    o.Deserialize(){ local obj="$1"; local serializer="$2"; local _data="${3:-}"
        if [ "$obj" == "" ]; then
            o.New; local obj="$_r"
        fi

        if [ "$_data" != "" ]; then
            o.Call "$serializer.Deserialize" "$_data"
        fi
        
        #keys can have Object Notation, like 'obj.key' or 'obj.other.key'
        o.Call "$serializer.List"; local keys=("${_r[@]}")
        if [ ! -z "$_error" ]; then
            _error="Could not list keys of serializer '$serializer': $_error"
            return 1
        fi

        for okey in "${keys[@]}"; do
            o.Call "$serializer.Get" "$okey"; local value="$_r"
            if [ ! -z "$_error" ]; then
                _error="Could not get value of key '$okey' from serializer '$serializer': $_error"
                return 1
            fi

            o.Set "$obj" "$okey" "$value"
            if [ ! -z "$_error" ]; then
                _error="Could not deserialize key '$okey' in object '$obj': $_error"
                return 1
            fi
        done

        _r="$obj"

        return 0
    }
    o.FromString(){ o.Deserialize "$@"; return $?; }

    o._serialize(){ local obj="$1"; local serializer="$2"; local _parent="${3:-}"; local _generateOutput=${4:-true}

        if [[ "$obj" == *.* ]]; then
            o.resolveFinalObjectAndKey "$obj" "InvalidKey"; local obj="$_r"; 
        fi

        if [[ "$serializer" == *.* ]]; then
            o.resolveFinalObjectAndKey "$serializer" "InvalidKey"; local serializer="$_r";
        fi

        o.ListProps "$obj"; local props=("${_r[@]}")

        if [ ! -z "$_error" ]; then
            _error="Could not list properties of object '$obj': $_error"
            return 1
        fi

        local prop=""
        for prop in "${props[@]}"; do
            #if the property is an object, serialize it recursively
            if o.IsObject "$obj.$prop"; then
                o._serialize "$obj.$prop" "$serializer" "$_parent$prop." false
            else
                #set the property in the serializer
                o.Get "$obj" "$prop"; local value="$_r"
                if [ ! -z "$_error" ]; then
                    _error="Could not get property '$prop' from object '$obj': $_error"
                    return 1
                fi

                #set the value in the serializer
                o.Call "$serializer.Set" "$_parent$prop" "$value"
            fi
        done

        if [ "$_generateOutput" == false ]; then
            _r=""
            _error=""
            return 0
        fi

        o.Call "$serializer.Serialize"
        if [ ! -z "$_error" ]; then
            _error="Could not serialize object '$obj' to serializer '$serializer': $_error"
            return 1
        fi

        _error=""
        return 0
    }

    o.Clone(){ local obj="$1"; 
        o.New; local newObj="$_r"
        for var in $(compgen -v | grep "^$obj"); do
            declare -n varRef="$var"
            local value="$varRef"

            declare -n newVarName="${var//$obj/$newObj}"
            newVarName="$value"
        done
    }; o.Copy(){ o.Clone "$@"; }

    #create an anonimous object, whose methods are received via arguments of 'newI'
    #arguments are strigns with bash function declarations
    #
    #it works by creating a random named class. When object is destroyed, the class is also destroyed.
    #
    #example:
    #   o.NewAnon \
    #       "Method1(){ echo Method1; }" \
    #       "Method2(){ echo Method2; }" \
    #       "Finalize(){ echo Finalize; }"instead

    #   obj="$_r" 
    #   o.Call "$obj" "Method1"
    #   o.Call "$obj" "Method2" 
    #   o.Destroy "$obj"

    __misc_anonymousClassCount=0
    o.NewAnon(){ 
        #get all interface methods
        local className="AnonimousClass_$RANDOM_$(( __misc_anonymousClassCount++ ))"

        for method in "$@"; do

            #evaluate the method implementation and create a function with the name of the class and method
            eval "$className.$method"
        done

        eval ''$className'.__Anonimous_Destroy() { 
            #list all methods of the class
            local bashFunctions=$(declare -F | grep "^declare -f '$className'\." | awk "{print \$3}")
            for method in $bashFunctions; do
                #remove the class name from the method name
                local methodName="${method#"'$className'."}"
                #unset the method
                unset -f "'$className'.$methodName"
            done
        }'

        o.New "$className"; local obj="$_r"
    }
    o.NewAnonymous(){ o.NewAnon "$@"; }
    o.NewA(){ o.NewAnon "$@"; }

    #Declare a interface. Instead you write a interface like this:
    #   IInterface.Method1(){ _error="Not implemented"; return 1; }
    #   IInterface.Method2(){ _error="Not implemented"; return 1; }
    #you can write:
    #   o.DeclareInterface IInterface Method1 Method2
    #
    #You can call this function multiple times to declare more methods in the same interface, but you cant declare the same method twice.
    o.DeclareInterface(){ 
        local interfaceName="$1"
        shift 1

        for method in "$@"; do
            #evaluate the method declaration and create a function with the name of the interface and method that returns "Not implemented"
            eval "$interfaceName.$method() { _error=\"Not implemented\"; return 1; }"
        done    
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
        #_r should, both,  contain the number of bytes written
        #return 0 if write successfully, 1 if error
        IReadWriter.Write(){ _error="Not implemented"; return 1; }

        #Read <amount of bytes>
        #Read the data from the string
        #_r will should contain the read data
        #_r_size should contain the size of the read data
        #_error should contain the error message if any
        #return 0 if read successfully, 1 if error
        IReadWriter.Read(){ _error="Not implemented"; return 1; }

        #CanRead
        #Check if the ReadWriter can read data
        #_r will should contain true or false
        #_error should contain the error message if any
        #return 0 if can read, 1 if cannot read
        IReadWriter.CanRead(){ _error="Not implemented"; return 1; }


        #Seek<byte address>
        #_r will should contain the new position after seek
        #_error should contain the error message if any. If the seek is not supported, _error should contain "seek is not supported"
        IReadWriter.Seek(){ _error="Not implemented"; return 1; }


        #CanWrite
        #Check if the ReadWriter can write data
        #_r will should contain true or false
        #_error should contain the error message if any
        #return 0 if can write, 1 if cannot write
        IReadWriter.CanWrite(){ _error="Not implemented"; return 1; }
    #}

    #ITextRadWriter(){
        ITextReadWriter.Write(){ :; }
        ITextReadWriter.WriteLine(){ :; }

        #Read <amount of bytes>
        #_r will should contain the read data
        ITextReadWriter.Read(){ :; }
        ITextReadWriter.ReadLine(){ :; }

        #Seek <line number>
        #_r will should contain the new position after seek
        #_error should contain the error message if any. If the seek is not supported, _error should contain "seek is not supported"
        ITextReadWriter.SeekToLine(){ :; }

        ITextReadriter.ReadAll(){ :; }
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
        IWorkable.WorkStep(){ _error="Not implemented"; return 1; }
    #}

    #IWorker is a class of works that can run by themselves, like a thread.
    #This class is hight dependent of Schedule library (shu/src/shellscript-fw/common/scheduler).
    #IWorker{
        #Receives a 'Scheduler' object to be able to schedule its work.
        IWorkder.Init(){ _error="Not implemented"; return 1; }
    #}

    #ILogger and INamedLogger {
        ILogger.Log(){ local logObject="$1"; local severity="$2"; local name="$3"; }

        ILogger.Trace(){ local $logObject="$1"; }
        
        ILogger.Debug(){ local $logObject="$1"; }

        ILogger.Info(){ local $logObject="$1"; }

        ILogger.Warn(){ local $logObject="$1"; }

        ILogger.Error(){ local $logObject="$1"; }

        ILogger.Fatal(){ local $logObject="$1"; }

        #INamedLogger class {
            InamedLogger.Log(){ local nLog="$1"; local severity="$2"; :; }

            INamedLogger.Trace(){ local nLog="$1"; :; }
            
            INamedLogger.Debug(){ local nLog="$1"; :; }

            INamedLogger.Info(){ local nLog="$1"; :; }

            INamedLogger.Warn(){ local nLog="$1"; :; }

            INamedLogger.Error(){ local nLog="$1"; :; }

            INamedLogger.Fatal(){ local nLog="$1"; :; }
        #}

        #should return, via _r variable, a INammedLogger object
        ILogger.GetNamedLogger(){ local name="$1"; }
    #}

    #ITranslator {
        #Translate a text
        #If you need to use placeholders, you can use the second argument to inform a placeholder marker and 
        #the rest of the arguments will be used as the values for the placeholders.
        #_r should return with the translated text
        #_error should contain the error message if any
        #return 0 if translated successfully, 1 if error
        ITranslator.T(){ local text="$1"; local _placeHolderMarker="${2:-}"; shift2; local _placeHoldersValues="$@"; }

        #Reverse translate a text using the translator
        #_r should return with the original text
        #_error should contain the error message if any
        #return 0 if reverse translated successfully, 1 if error
        ITranslator.ReverseT(){ local translatedText="$1"; }
    #}


#return _r with a text that can be printed to the console. The line length is 
#defined by tput cols, or 80 if tput is not available.
#_print ($2) can be used to control if the line should be printed or not. The
#default behavior is to print the line (_print = true).
misc.CreateHorizontalLine(){ local _centralText="${1:-}"; local _char="${2:-"-"}"; local _print="${3:-true}"
    local _length=$(tput cols 2>/dev/null || echo 80)
    if [ -z "$_length" ] || [ "$_length" -le 0 ]; then
        _length=80
    fi

    local result=$(printf "%${_length}s" | tr ' ' "$_char")

    if [ -n "$_centralText" ]; then
        local centralTextLength=${#_centralText}
        if [ "$centralTextLength" -ge "$_length" ]; then
            _centralText="${_centralText:0:_length}"
            centralTextLength=$_length
        fi

        local sideLength=$(( (_length - centralTextLength) / 2 ))
        local extraChar=""
        if [ $(( (_length - centralTextLength) % 2 )) -ne 0 ]; then
            extraChar="$_char"
        fi

        result="$(printf "%${sideLength}s" | tr ' ' "$_char")$_centralText$(printf "%${sideLength}s" | tr ' ' "$_char")$extraChar"
    fi


    _r="$result"
    if [ "$_print" == "true" ]; then
        printf "%s\n" "$_r"
    fi
    return 0
}

#gets a argument by its name. The if function is not case-sensitive and allows three formats for the argument: --arg=value, --arg:value and --arg value.
misc.GetArgByName(){ local argName="$1"; local defaultValue="$2"; shift 2
    local argValue="$defaultValue"
    local args=("$@")
    local i

    #convert argName to lower case for case-insensitive comparison
    local argName=$(echo "$argName" | tr '[:upper:]' '[:lower:]')

    for ((i=0; i<${#args[@]}; i++)); do
        local arg="${args[$i]}"
        local argLow=$(echo "$arg" | tr '[:upper:]' '[:lower:]')

        if [[ "$argLow" == "$argName="* ]]; then
            argValue="${arg#*=}"
            break
        elif [[ "$argLow" == "$argName:"* ]]; then
            argValue="${arg#*:}"
            break
        elif [[ "$argLow" == "$argName" ]]; then
            if [ $((i + 1)) -lt ${#args[@]} ]; then
                argValue="${args[$((i + 1))]}"
            fi
            break
        fi
    done

    _r="$argValue" 
    return 0
}


#Find arg using multiple possible names. This is useful when you want to allow multiple names for the same argument, like --help and -h.
#possibleNames is a list of possible names for the argument, separated by space. For example: "--help -h"
#example: misc.FindArg "--help -h" "default value" "$@"
misc.FindArg(){ local possibleNames="$1"; local defaultValue="$2"; shift 2

    local argValue="$defaultValue"
    local args=("$@")
    local i

    local originalIFS="$IFS"

    IFS=' ' read -r -a possibleNamesArray <<< "$possibleNames"
    for possibleName in "${possibleNamesArray[@]}"; do
        misc.GetArgByName "$possibleName" "" "${args[@]}"
        if [ -n "$_r" ]; then
            argValue="$_r"
            break
        fi
    done

    _r="$argValue"
    IFS="$originalIFS"
    return 0
}

#identify the lines in the txt and add the prefix in each line
misc.IndentLines(){ local indentText="$1"; local text="$2"
    local indentedText=""
    while IFS= read -r line; do
        indentedText+="$indentText$line"$'\n'
    done <<< "$text"

    _r="$indentedText"
    return 0
}

misc.GetOnly(){ local input="$1"; local _validChars="${2:-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_}"
    local result=""
    local i
    for ((i=0; i<${#input}; i++)); do
        local char="${input:$i:1}"
        if [[ "$_validChars" == *"$char"* ]]; then
            result+="$char"
        fi
    done
    _r="$result"
}

#misc.stackTraceToString itself is not printed
misc.StackTraceToString(){ local _souldPrintItCallback="${1:-"_f(){ _r=true; }; _f"}";
    local i=0
    local callStack=""
    local printedCount=0
    while caller $i > /dev/null; do
        local callerInfo="$(caller $i)"

        local lineNumber="$(echo "$callerInfo" | awk '{print $1}')"
        local fileName="$(echo "$callerInfo" | awk '{print $3}')"
        local functionName="$(echo "$callerInfo" | awk '{print $2}')"
        callerInfo="$functionName() in $fileName:$lineNumber"

        eval "$_souldPrintItCallback \"$functionName\" \"$fileName\" \"$lineNumber\""; local shouldPrintIt="$_r"

        if [ "$shouldPrintIt" != "true" ]; then
            ((i++))
            continue
        fi

        if [[ "$printedCount" -eq 0 ]]; then
            callStack+="(most recent) ";
        else
            callStack+="+ called by ";
        fi
        ((printedCount++))

        callStack+="\"$callerInfo\""

        ((i++))
    done

    _r="$callStack" 
    
}


#evaluate arguments and prints the stack trace if any error occurs (returns != 0 or _error != "")
misc.Call(){
    _error=""
    eval "$@"; local retCode="$?"
    if [[ "$retCode" -ne 0 || -n "$_error" ]]; then
        local func="$@"
        #func="${func:0:100}..."

        local tmpError="error calling (return code $retCode) '$func'"
        if [ "$_error" != "" ]; then
            tmpError+=": $_error"
        fi
        misc.StackTraceToString
        misc.PrintError "$tmpError. Call stack:: $_r"
        _error="$tmpError"
    fi
    
    return $retCode
}
Call(){ misc.Call "$@"; return $?; }
misc.Eval(){ misc.Call "$@"; return $?; }

#printing messages and errors {
    misc.PrintGreen(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;32m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightGreen(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;92m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintRed(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;31m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightRed(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;91m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintYellow(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;33m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightYellow(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;93m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBlue(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;34m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightBlue(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;94m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintCyan(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;36m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightCyan(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;96m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintMagenta(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;35m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightMagenta(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;95m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintGray(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;90m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBrightGray(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[0;37m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintBold(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[1m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    misc.PrintItalic(){ local message="$1"; local keepOpened="${2:-}"
        printf "\033[3m$message"
        if [ "$keepOpened" != "true" ]; then
            printf "\033[0m"
        fi
    }

    #prints contextual erros.
    #erros are nested by ':'
    #print each erro in a single line
    #use identation to show nesting
    misc.PrintError(){
        local error="$1"
        local _currIdentation="$2"
        local _currPrefix_="${3:-}"
        
        local currError=""

        if [[ "$error" == *": "* ]]; then
            #currError="${error%%: *}:"
            currError="${error%%: *}"
            error="${error#*: }"
        else
            currError="$error"
            error=""
        fi
        misc.PrintError.printSameLevelError "$currError" "$_currIdentation" "$_currPrefix_"
        if [[ -n "$error" ]]; then
            #change prefix of next errors to ': '
            misc.PrintError "$error" "$_currIdentation  " "⤷ "
        fi
    }

    #same level erros are erros separated by '+' and should be printed in induaviadual lines, but with the same identation
    misc.PrintError.printSameLevelError(){
        local error="$1"
        local currIdentation="$2"
        local _prefix_="$3"

        local currError=""
        if [[ "$error" == *"+ "* ]]; then
            currError="${error%%"+ "*}"
            error="${error#*"+ "}"
        else
            currError="$error"
            error=""
        fi

        #print to stderr
        misc.PrintRed "$currIdentation$_prefix_$currError\n" >&2
        if [[ -n "$error" ]]; then
            #change prefix of next errors to '+ '
            misc.PrintError.printSameLevelError "$error" "$currIdentation" "+ "
        fi
    }
#}

#allow to use optional pattern in shellscript. Scroll over the arguments looking for paterns --key:value,  --key=value and --key value.
#For each one found, the property 'key' of the object 'obj' is set to the value 'value' (using o.Set property).
#If the same key is found more than once, an array is created on the object 'obj' with the key 'key' and the values are added to this array.
#
#Example 1:
#   myFunc(){
#       o.New; local obj="$_r";
#       misc.parseOptions $obj "$@"
#   }
#   myFunc --p1=value1 --p2:value2 --p3 value3
#   # will set the properties 'p1', 'p2' and 'p3' of the object '$obj' (inside func 'myFunc') to the values 'value1', 'value2' and 'value3', respectively.
#
#Example 2: Using Go-like optional (spawn subshell)
#   myFunc(){
#       o.New; local obj="$_r";
#       misc.parseOptions $obj --with-p1=value1 --with-p2:value2 --with-p3 value3
#   }
# 
#   withFile(){
#       echo "--file $1"
#   }
#   
#   myFunc $(withFile "myfile.txt")
#   # will set the properties 'file' of the object '$obj' (inside func 'myFunc') to the values 'value1', 'value2' and 'value3', respectively.
#
#       o.New; local obj="$_r";}
# _r returns with amount of 'digested' arguments
misc.ParseOptions(){
    local obj="$1"; shift
    local digested=0
    while true; do
        local arg="${!i}"; ((i++))
        if [[ -z "$arg" ]]; then
            break
        fi

        #check if argument begins with "--with-"
        if [[ "$arg" == --* ]]; then
            local key=""
            local value=""
            #remove "--" from the argument
            arg=${arg:2}
            #check if $arg contains ':' or  '='
            if [[ "$arg" == *":"* ]] || [[ "$arg" == *"="* ]]; then
                #split the argument by ':' or '='
                key="${arg%%:*}"; key="${key%%=*}"
                value="${arg#*:}"; value="${value#*=}"
                digested=$((digested + 1))

            else
                #value is in the next agument
                key="$arg"
                value="${!i}"; ((i++))
                digested=$((digested + 2))
            fi

            #replace '-' by '_' in key
            key="${key//-/_}"

            o.Set "$obj" "$key" "$value"
        fi
    done

    _r=$digested
}


shu.RunCommandAndInterceptStdout() {
    local command="$1"
    local callback="$2"
    local tempFolder="$(mktemp -d)"
    rm -rf "$tempFolder"
    mkdir -p "$tempFolder"


    local fifo="$tempFolder/fifo"
    mkfifo "$fifo"
    (
        set -o pipefail

        eval "$command; retCode=\$?; echo \$retCode > $tempFolder/retCode" \
            2> >(while IFS= read -r line; do echo "stderr:$line"; done) \
            | while IFS= read -r line; do 
                if [[ "$line" == stderr:* ]]; then
                    echo "$line"
                else
                    echo "stdout:$line"
                fi
            done

        echo "end:end"

    ) >> "$fifo" &

    local pid=$!
    local retCode=""
    while IFS= read -r line; do
        if [[ "$line" == end:* ]]; then
            break
        fi

        local prefix="${line%%:*}"
        local content="${line#*:}"

        eval "$callback \"\$content\" \"$prefix\""

        if [[ "$prefix" == "stderr" ]]; then
            echo "$content" >> $tempFolder/stderr.log
        else
            echo "$content" >> $tempFolder/stdout.log
        fi

    done < "$fifo"

    rm -f "$fifo"

    local retCode=0        
    if [[ -f "$tempFolder/retCode" ]]; then
        retCode=$(cat "$tempFolder/retCode")
        rm -f "$tempFolder/retCode"
    fi
    
    if [ -f "$tempFolder/stderr.log" ]; then
        _error=$(cat "$tempFolder/stderr.log")
    else
        _error=""
    fi
    _r=$(cat "$tempFolder/stdout.log")
    rm -rf "$tempFolder"
    return $retCode
}

#hook functions (written in shellscript)
#original func ($funcName) will be renamed to another name. When it be called, $hookFunc will be called and
#the name of the original funcion will be passed as first parameters.
misc_hookIdCounter=0
misc.HookFunction(){ local funcName="$1"; local hookFunc="$2"; shift 2
    local newFuncName="${funcName}_original_${misc_hookIdCounter}"
    misc_hookIdCounter=$((misc_hookIdCounter + 1))

    #code of original function
    originalCode="$(declare -f "$funcName")"

    #replace the name of the original function
    originalCode="${originalCode/$funcName/$newFuncName}"

    eval "$originalCode"

    eval "$funcName() { $hookFunc \"$newFuncName\" \"\$@\"; }"
}

#Load and cache a shellscript from a URL. If the file was already loaded and is not older than maxCacheAgeInDays, the cached version will be used.
misc.SourceUrl(){ local url="$1"; local cacheFolder="${2:-./run/cache}"; local maxCacheAgeInDays="${3:-7}"
    mkdir -p "$cacheFolder"
    local onlyName="${url##*/}"
    local cache_file="$cacheFolder/$onlyName_$(echo -n "$url" | md5sum | awk '{print $1}').sh"

    if [ -f "$cache_file" ]; then
        local modTime=$(stat -c %Y "$cache_file")
        local currentTime=$(date +%s)
        local ageInSeconds=$((currentTime - modTime))
        local maxAgeInSeconds=$((maxCacheAgeInDays * 24 * 60 * 60))

        if [ $ageInSeconds -lt $maxAgeInSeconds ]; then
            source "$cache_file"
            return 0
        fi
    fi
    
    rm -f "$cache_file"

    local result=0
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL "$url" -o "$cache_file"
        result=$?
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$cache_file"
        result=$?
    fi
    
    if [[ $result -ne 0 ]]; then
        echo "Error: cannot load SHU misc.sh. Please check your internet connection or source the file manually." >&2
        return 1
    fi

    source "$cache_file"
    return 0
}
