#!/bin/bash

#set and get properties of the project in a temporary folder (.shu/project-vars)

shu.pvars.Main(){
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        shu.pvars.Help
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
    "shu.pvars.$func" "$@"
    return $?
}

shu.pvars.Help(){
    echo "pvars <subcommand>      - Allow use of local variables for your project. Besides you can use 'pvars' in the terminal, it is focused in project automation. Note: Variables are stored inside .shu/vars folder and are deleted by shu clean command. Also, variables should not be versionated, instead, is is supposed to be used for temporary data used by automation scripts. If you need to store data permanently, use 'pprops' command (pprops store data in the shu.yaml file)."
    echo "  subcommands:"
    echo "    set <key> <value>     - Set a variable with the specified key and value. You can set multiple properties at once by providing multiple key-value pairs."
    echo "    get <key>             - Get the value of a variable by its key."
    echo "    list [callback]       - List all variables of the project."
    echo "      callback:             - If provided, the callback will be called for each variable with the key and value as arguments. If not provided, the variables will be printed to the console."
    echo "    remove <key>          - Remove a variable by its key."
    echo "    addarrayitem <arrayKey> <value> - Add an item to an array variable."
    echo "    listarrayitems <arrayKey>"
    echo "                          - List items of an array variable."
    echo "    removearrayitem <arrayKey> <index> - Remove an item from an array variable by index."
    echo "    addarrayobject <arrayKey> [key:value]... - Add an object to an array variable with key-value pairs."
    echo "    getobjectfromarray <arrayKey> <index> [callback] - Get an object from an array variable by index and optionally call a callback with its key-value pairs."
}


#set a single property
shu.pvars.Set(){
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
    
    mkdir -p "$SHU_PROJECT_ROOT_DIR/.shu/project-vars"
    echo "$value" > "$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$key"    
    if [ $? -ne 0 ]; then
        _error="Failed to set property '$key'."
        return 1
    fi


    #remain args?
    if [ $# -gt 0 ]; then
        #shu.pvars.Set "$@"
        shu.pvars.Set "$@"
    fi

}

#prints the value of a property
shu.pvars.Get(){
    local pkey="$1"
    if [ -z "$pkey" ]; then
        _error="Key is required."
        return 1
    fi
    shift;

    if [ ! -f "$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$pkey" ]; then
        _error="Property '$pkey' not found."
        return 1
    fi
    _r=$(<"$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$pkey")
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

#list all variables of the project. if _callback ($1) is provided, it is called for each property, else the project-properties are printed.
shu.pvars.List(){ local _callback="${1:-}"; shift
    
    shu_pvars_list_props=()
    if [ ! -d "$SHU_PROJECT_ROOT_DIR/.shu/project-vars" ]; then
        return 0
    fi

    while IFS= read -r -d '' file; do
        local key=$(basename "$file")
        local value=$(<"$file")
        shu_pvars_list_props+=("$key:$value")
    done < <(find "$SHU_PROJECT_ROOT_DIR/.shu/project-vars" -type f -print0)

    local vars=("${shu_pvars_list_props[@]}")
    unset shu_pvars_list_props

    for prop in "${vars[@]}"; do
        local key="${prop%%:*}"
        shu.pvars.Get "$key" --no-print; local value="$_r"

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
shu.pvars.Remove(){ local key="$1"; shift;
    if [ -z "$key" ]; then
        _error="Key is required."
        return 1
    fi

    if [ ! -f "$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$key" ]; then
        _error="Property '$key' not found."
        return 1
    fi
    
    rm -f "$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$key"

    #remain args?
    if [ $# -gt 0 ]; then
        shu.pvars.Remove "$@"
    fi
}

#add an array property
shu.pvars.Addarrayitem(){ local arrayKey="$1"; local value="$2"; shift 2
    #each valu contains a value.
    #a value file is named as <arrayKey>_<index>
    #the file <arrayKey>_<count> contains the count of items in the array
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi

    if [ -z "$value" ]; then
        _error="Value is required."
        return 1
    fi

    mkdir -p "$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$arrayKey"
    shu.pvars.Get "$arrayKey""_count" --no-print; local count="$_r"
    if [ -z "$count" ]; then
        count=0
    fi

    shu.pvars.Set "$arrayKey""_$count" "$value"
    if [ $? -ne 0 ]; then
        _error="Failed to set property '$arrayKey'."
        return 1
    fi

    count=$((count + 1))
    shu.pvars.Set "$arrayKey""_count" "$count"
    if [ $? -ne 0 ]; then
        _error="Failed to set property '$arrayKey' count."
        return 1
    fi

    #remain args?
    if [ $# -gt 0 ]; then
        shu.pvars.Addarrayitem "$arrayKey" "$@"
    fi
}

#list the items of an array property. If _callback ($1) is provided, it is called, else the items are printed.
shu.pvars.Listarrayitems(){ local arrayKey="$1"; local _callback="${2:-}"
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi

    shu.pvars.Get "$arrayKey""_count" --no-print; local count="$_r"
    if [ -z "$count" ]; then
        echo "Array '$arrayKey' is empty."
        return 0
    fi

    for ((i = 0; i < count; i++)); do
        shu.pvars.Get "$arrayKey""_$i" --no-print; local value="$_r"

        if [ -n "$_callback" ]; then
            eval "$_callback \"$i\" \"$value\""
            if [ $? -ne 0 ]; then
                _error="Error calling callback for array '$arrayKey' at index $i: $_error"
                return 1
            fi
        else
            echo "$value"
        fi
    done
    return 0
}

#remove an item from an array property by index
shu.pvars.Removearrayitem(){
    local arrayKey="$1"; local index="$2"; shift 2
    if [ -z "$arrayKey" ]; then
        _error="Array key is required."
        return 1
    fi
    if [ -z "$index" ]; then
        _error="Index is required."
        return 1
    fi

    shu.pvars.Get "$arrayKey""_count" --no-print; local count="$_r"
    if [ -z "$count" ]; then
        _error="Array '$arrayKey' is empty."
        return 1
    fi

    if [ "$index" -ge "$count" ] || [ "$index" -lt 0 ]; then
        _error="Index '$index' out of bounds for array '$arrayKey'."
        return 1
    fi

    rm -f "$SHU_PROJECT_ROOT_DIR/.shu/project-vars/$arrayKey""_$index"

    #shift all items after the removed item
    for ((i = index + 1; i < count; i++)); do
        shu.pvars.Get "$arrayKey""_$i" --no-print; local value="$_r"
        shu.pvars.Set "$arrayKey""_$((i - 1))" "$value"
    done

    #decrease the count
    count=$((count - 1))
    shu.pvars.Set "$arrayKey""_count" "$count"
}

shu.pvars.Main "$@"
return $?