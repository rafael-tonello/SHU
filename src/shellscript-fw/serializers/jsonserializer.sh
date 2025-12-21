#!/bin/bash
#TODO: as this library is part of shu, and misc is (probabily) already loaded, just check if misc is rally loaded

JsonSerializer.New(){
    #ceck for jq command
    if ! command -v jq &> /dev/null; then
        _r=""
        _error="jq command not found, please install jq to use JsonSerializer"
        return 1
    fi

    _error=""
    o.New "JsonSerializer"; local serializer="$_r"
    o.Set "$serializer.count" 0
    return 0
}

JsonSerializer.Set(){ local ser="$1"; local kkey="$2"; local value="$3"
    o.Get "$ser.count"; local count="$_r"
    o.Set "$ser.count" $((count + 1))
    o.Set "$ser" "item_$count""_kkey" "$kkey"
    o.Set "$ser" "item_$count""_value" "$value"
    _error=""
    return 0
}

JsonSerializer.Get(){ local ser="$1"; local kkey="$2"
    o.Get "$ser.count"; local count="$_r"
    for ((i=0; i<count; i++)); do
        o.Get "$ser.item_$i""_kkey"; local itemKkey="$_r"
        if [[ "$itemKkey" == "$kkey" ]]; then
            o.Get "$ser.item_$i""_value"; _r="$_r"
            _error=""
            return 0
        fi
    done
    _error="Kkey not found: $kkey"
    return 1
}

JsonSerializer.List(){ local ser="$1"
    o.Get "$ser.count"; local count="$_r"
    local kkeys=()
    for ((i=0; i<count; i++)); do
        o.Get "$ser.item_$i""_kkey"; kkeys+=("$_r")
    done
    _r=("${kkeys[@]}")
    _error=""
    return 0
}

JsonSerializer.Serialize(){ local ser="$1"
    #serialie using jq (object notation)
    JsonSerializer.List "$ser"; local kkeys=("${_r[@]}")
    
    _r="$(for kkey in "${kkeys[@]}"; do
        JsonSerializer.Get "$ser" "$kkey"
        local value="$_r"
        jq -n --arg path "$kkey" --arg v "$value" '
        reduce ( ($path | split(".")) ) as $p ( {}; setpath($p; $v) )
        '
    done | jq -s 'reduce .[] as $item ({}; . * $item)')"

    _error=""
    return 0
}

JsonSerializer.Deserialize(){ local ser="$1"; local data="$2"; parentName="${3:-}"
    #clear current serializer
    o.Set "$ser.count" 0

    JsonSerializer._ideserialize "$ser" "$data" "$parentName"
}

JsonSerializer._ideserialize(){ local ser="$1"; local data="$2"; local parentName="$3"
    if [ "$parentName" != "" ]; then
        parentName="$parentName."
    fi

    #deserialize using jq
    if ! echo "$data" | jq empty &> /dev/null; then
        _error="Invalid JSON data"
        return 1
    fi


    #iterate over the kkeys and values in the JSON object
    for kkey in $(echo "$data" | jq -r 'keys[]'); do

        local value=$(echo "$data" | jq -r --arg k "$kkey" '.[$k]')
        
        #check if value is a json object
        if echo "$value" | jq empty &> /dev/null && [[ $(echo "$value" | jq 'type') == "\"object\"" ]]; then
            JsonSerializer._ideserialize "$ser" "$value" "$parentName$kkey"
        else
            JsonSerializer.Set "$ser" "$parentName$kkey" "$value"
        fi
    done

    _error=""
    return 0
}
