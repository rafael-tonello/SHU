#!/bin/bash

#set and get properties of the project in the shu.yaml file
#pprops is a shorthand for 'p'roject 'prop'ertie's'
shu.pprops.Main(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.pprops.Help
        return 0
    fi


    if [ "$SHU_PROJECT_ROOT_DIR" == "" ]; then
        _error="$ERROR_COMMAND_REQUIRES_SHU_PROJECT"
        return 1
    fi
    
    
    #convert all $1 to lowercase
    local func=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    local func=$(echo "$func" | awk '{print toupper(substr($0,0,1)) substr($0,2)}')
    shift
    "shu.pprops.$func" "$@"
    return $?
}

shu.pprops.Help(){
    echo "pprops <subcommand>      - Manage project properties, data and key-value infomation. These properties are key-value pairs stored in the 'shu.yaml' file of the project, and allow you to store data and states for your project automation or whatever you want :D . They can be used to store configuration values, settings, or any other data related to the project. You can use object notation in 'keys', so you can store structured data."
    echo "  subcommands:"
    echo "    set <key> <value>     - Set a property with the specified key and value. You can set multiple properties at once by providing multiple key-value pairs."
    echo "    get <key>             - Get the value of a property by its key."
    echo "    list [callback]       - List all properties of the project."
    echo "      callback:             - If provided, the callback will be called for each property with the key and value as arguments. If not provided, the properties will be printed to the console."
    echo "    remove <key>          - Remove a property by its key."
    echo "    addarrayitem <arrayKey> <value> - Add an item to an array property."
    echo "    listarrayitems <arrayKey>"
    echo "                          - List items of an array property."
    echo "    removearrayitem <arrayKey> <index> - Remove an item from an array property by index."
    echo "    addarrayobject <arrayKey> [key:value]... - Add an object to an array property with key-value pairs."
    echo "    getobjectfromarray <arrayKey> <index> [callback] - Get an object from an array property by index and optionally call a callback with its key-value pairs."
}


#set a single property
shu.pprops.Set(){
    local key="$1"
    local value="$2"
    local toShift=2;
    if [ -z "$key" ]; then
        _error="Key is required."
        return 1

        if [[ "$arg" == *":"* ]]; then
            key="${arg%%:*}"
            value="${arg#*:}"
            toShift=1
        elif [[ "$arg" == *"="* ]]; then
            key="${key%%=*}"
            value="${value#*=}"
            toShift=1
        fi
    fi
    shift $toShift


    if [ -z "$value" ]; then
        _error="Value is required."
        return 1
    fi
    
    shu.yaml.set "shu.yaml" ".project-data.$key" "$value"
    
    if [ $? -ne 0 ]; then
        _error="Failed to set property '$key'."
        return 1
    fi
    
    echo "Property '$key' set to '$value'."


    #remain args?
    if [ $# -gt 0 ]; then
        #shu.pprops.Set "$@"
        shu.pprops.Set "$@"
    fi

}

#prints the value of a property
shu.pprops.Get(){
    local pkey="$1"
    if [ -z "$pkey" ]; then
        _error="Key is required."
        return 1
    fi
    shift;

    shu.yaml.get "shu.yaml" ".project-data.$pkey"
    if [ $? -ne 0 ]; then
        _error="Failed to get property '$pkey': $_error."
        return 1
    fi

    _error=""
    if [ "$1" == "--no-print" ] || [ "$1" == "-n" ]; then
        return 0
    fi
    echo "$_r"
    return 0
}

#list all properties of the project. if _callback ($1) is provided, it is called for each property, else the project-data are printed.
shu.pprops.List(){ local _callback="${1:-}"; shift
    shu.yaml.listProperties "shu.yaml" ".project-data"; local retCode=$?; local props=("${_r[@]}")
    if [ $retCode -ne 0 ]; then
        _error="Failed to list properties."
        return 1
    fi

    if [ -z "$_r" ]; then
        echo "No properties found."
    fi

    for prop in "${props[@]}"; do
        local key="${prop%%:*}"
        shu.pprops.Get "$key" --no-print; local value="$_r"

        if [ -n "$_callback" ]; then
            eval "$_callback \"$key\" \"$value\""
            if [ $? -ne 0 ]; then
                _error="Error calling callback for property '$key': $_error"
                return 1
            fi
        else
            echo "$key: $value"
        fi
    done
    return 0
}

#remove a property from the project
shu.pprops.Remove(){ local key="$1"; shift;
    if [ -z "$key" ]; then
        _error="Key is required."
        return 1
    fi

    shu.yaml.remove "shu.yaml" ".project-data.$key"
    
    if [ $? -ne 0 ]; then
        _error="Failed to remove property '$key'."
        return 1
    fi

    echo "Property '$key' removed."

    #remain args?
    if [ $# -gt 0 ]; then
        shu.pprops.Remove "$@"
    fi
}

#add an array property
shu.pprops.Addarrayitem(){ local arrayKey="$1"; local value="$2"; shift 2
    shu.yaml.addArrayElement "shu.yaml" ".project-data.$arrayKey" "$value"
    
    if [ $? -ne 0 ]; then
        _error="Failed to set property '$key'."
        return 1
    fi

    echo "'$value' added to '$arrayKey'."

    #remain args?
    if [ $# -gt 0 ]; then
        #shu.pprops.Set "$@"
        shu.pprops.Set "$arrayKey" "$@"
    fi
}

#list the items of an array property. If _callback ($1) is provided, it is called, else the items are printed.
shu.pprops.Listarrayitems(){ local arrayKey="$1"; local _callback="${2:-}"
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi  
    
    local index=0;
    local errors=""
    while true; do
        shu.yaml.getArrayElement "shu.yaml" ".project-data.$arrayKey" "$index"
        if [ $? -ne 0 ]; then
            if [ "$_error" == "$ERROR_INDEX_OUT_OF_BOUNDS" ]; then
                _error=""
                break
            else
                _error="Failed to get array property '$arrayKey' at index $index."
                return 1
            fi
        fi
        if [ ! -z "$_callback" ]; then
            _error=""
            eval "$_callback \"$_r\""
            if [ "$_error" != "" ]; then
                if [ -a "$errors" ]; then
                    errors="$_error"
                else
                    errors+="+ $_error"
                fi
            fi
        else
            echo "$_r"
        fi
        index=$((index + 1))
    done

    if [ -n "$errors" ]; then
        _error="Error(s) occurred while listing array items: $errors"
        return 1
    fi

    return 0
}

#remove an item from an array property by index
shu.pprops.Removearrayitem(){
    local arrayKey="$1"; local index="$2"; shift 2
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi
    if [ -z "$index" ]; then
        _error="Index is required."
        return 1
    fi
    
    shu.yaml.removeArrayElement "shu.yaml" ".project-data.$arrayKey" "$index"
    if [ $? -ne 0 ]; then
        _error="Failed to remove item from array '$arrayKey' at index $index."
        return 1
    fi

    echo "Item at index $index removed from array '$arrayKey'."
    #remain args?
    if [ $# -gt 0 ]; then
        shu.pprops.RemoveArrayItem "$arrayKey" "$@"
    fi
}

#add a object to an array. Each argument should be in the format "key:value"
shu.pprops.Addarrayobject(){
    local arrayKey="$1"; shift
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi

    if [ $# -eq 0 ]; then
        _error="At least one key:value pair is required."
        return 1
    fi
    
    shuYamlKeValueArgs=()
    while true; do
        local arg="$1"; shift
        local key="$arg"
        
        local value=""
        #separete keyvalue by ':'
        if [[ "$arg" == *":"* ]]; then
            key="${arg%%:*}"
            value="${arg#*:}"
        elif [[ "$arg" == *"="* ]]; then
            key="${arg%%=*}"
            value="${arg#*=}"
        else
            value="$1"; shift
        fi

        shuYamlKeValueArgs+=("$key" "$value")
    done

    if [ ${#shuYamlKeValueArgs[@]} -eq 0 ]; then
        _error="No key:value pairs provided."
        return 1
    fi

    shu.yaml.addObjectToArray "shu.yaml" ".project-data.$arrayKey" "${shuYamlKeValueArgs[@]}"
}


#prints (or calls _callback) a/with a sequence os key:value pairs of an object in an array property.
shu.pprops.getobjectfromarray(){ local arrayKey="$1"; local index="$2"; shift 2; local _callback="${1:-}"
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi
    if [ -z "$index" ]; then
        _error="Index is required."
        return 1
    fi

    shu.yaml.getObjectFromArray "shu.yaml" ".project-data.$arrayKey" "$index"
    if [ $? -ne 0 ]; then
        _error="Failed to get object from array '$arrayKey' at index $index."
        return 1
    fi

    if [ ! -z "$_callback" ]; then
        eval "$_callback \"$_r\""
        if [ "$?" -ne 0 || ! -z "$_error" ]; then
            _error="Failed to process object from array '$arrayKey' at index $index: $_error"
            return 1
        fi
    else
        echo "$_r"
    fi
}

shu.pprops.Main "$@"
return $?