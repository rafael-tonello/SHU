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

JsonSerializer.Set(){ local ser="$1"; local key="$2"; local value="$3"
    o.Get "$ser.count"; local count="$_r"
    o.Set "$ser.count" $((count + 1))
    o.Set "$ser" "item_$count""_key" "$key"
    o.Set "$ser" "item_$count""_value" "$value"
    _error=""
    return 0
}

JsonSerializer.Get(){ local ser="$1"; local key="$2"
    o.Get "$ser.count"; local count="$_r"
    for ((i=0; i<count; i++)); do
        o.Get "$ser.item_$i""_key"; local itemKey="$_r"
        if [[ "$itemKey" == "$key" ]]; then
            o.Get "$ser.item_$i""_value"; _r="$_r"
            _error=""
            return 0
        fi
    done
    _error="Key not found: $key"
    return 1
}

JsonSerializer.List(){ local ser="$1"
    o.Get "$ser.count"; local count="$_r"
    local keys=()
    for ((i=0; i<count; i++)); do
        o.Get "$ser.item_$i""_key"; keys+=("$_r")
    done
    _r=("${keys[@]}")
    _error=""
    return 0
}

JsonSerializer.Serialize(){ local ser="$1"
    #serialie using jq (object notation)
    JsonSerializer.List "$ser"; local keys=("${_r[@]}")
    
    _r="$(for key in "${keys[@]}"; do
        JsonSerializer.Get "$ser" "$key"
        local value="$_r"
        jq -n --arg path "$key" --arg v "$value" '
        reduce ( ($path | split(".")) ) as $p ( {}; setpath($p; $v) )
        '
    done | jq -s 'reduce .[] as $item ({}; . * $item)')"

    _error=""
    return 0
}

JsonSerializer.Deserialize(){ local ser="$1"; local data="$2"
    #deserialize using jq
    if ! echo "$data" | jq empty &> /dev/null; then
        _error="Invalid JSON data"
        return 1
    fi

    #clear current serializer
    o.Set "$ser.count" 0

    #iterate over the keys and values in the JSON object
    for key in $(echo "$data" | jq -r 'keys[]'); do
        local value=$(echo "$data" | jq -r --arg k "$key" '.[$k]')
        JsonSerializer.Set "$ser" "$key" "$value"
    done

    _error=""
    return 0
}
