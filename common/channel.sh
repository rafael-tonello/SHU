#!/bin/bash

#this is a golang inspirated channel. It allow multiprocess and subshells state exchange.
#It differes from golang channle it alllow you set a lot of properties before send data: Go lang channels are typed and can transfer more complex types, like maps, tructs, and user-defined types. Shell script have not native structs, and needs aditional frameworks like SHU, to simulate complex data types. So this channel allow you to set properties before sending data.

#you should call 'Channel.Set' to set properties before sending data. When ready, you call 'Channel.Send' to send the data. In the destination you can call 'Channel.Wait' to wait for data to arrive. Data can be obtained with 'Channel.Get'.

#Channel.Wait have only one argument, that is bool and is default to false. If true, Channel.Wait will create a SHU struct (via o.New) and will populate it with the Channel setted properties. If some property is set with object notation (like 'prop.subprop'), the result object will have the same structure (prop will be a child object with propety called 'subprop').

#Example of usage:
# Channel.New; local ch="$_r"

# (
#     #subshell
#     Channel.Set "$ch" "message" "Hello from subshell"
#     Channel.Set "$ch" "value" "42"
#     sleep 2
#     Channel.Send "$ch"
# )&

# Channel.WaitNext "$ch" true; local obj="$_r"
# o.Get "$obj.message"; echo "Received message: $_r"
# o.Get "$obj.value"; echo "Received value: $_r"

#create a new channel.
#returns the channel object via _r variable
#object can be securely shared with subshells. 
#If you want to use the object for a 'multi process' communicatin, you can provide a filename as argument

sourceUrl(){ local url="$1"; local cacheFolder="${2:-./run/cache}"; local maxCacheAgeInDays="${3:-7}"
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

#check SHU_MISC_LOADED=true
if [[ "$SHU_MISC_LOADED" != "true" ]]; then
    sourceUrl "https://raw.githubusercontent.com/rafael-tonello/SHU/refs/heads/main/src/shellscript-fw/common/misc.sh" || exit 1
fi

Channel.New(){ local fname="${1:-}"
    if [[ -z "${fname}" ]]; then
        #random temporary file
        #try create at shm (check if available)
        if [[ -d "/dev/shm" ]]; then
            #try create temp file at /dev/shm
            echo "test" > /dev/shm/.shm_test_file 2>/dev/null
            if [[ $? -eq 0 ]]; then
                rm -f /dev/shm/.shm_test_file

                fname="$(mktemp /dev/shm/channel.XXXXXX)"
            else
                fname="$(mktemp /tmp/channel.XXXXXX)"
            fi
        else
            fname="$(mktemp /tmp/channel.XXXXXX)"
        fi
    fi
    o.New "Channel"; local ch="$_r"
    o.Set "$ch._fname" "$fname"
    o.Set "$ch.propCount" "0"

    o.Set "$ch.nextFileIndex" "0"
}

#this will be called when you call o.Destroy. Is high recommended to call o.Destroy in the same shell that created the object.
Channel.OnFinalize(){
    Channel.Restart "$1"
}

#reset all properties in the channel and remove all pending data that have been sent but not yet received
Channel.Restart(){
    #erase all files
    o.Get "$1._fname"; local fname="$_r"
    rm -f "${fname}."*

    o.Set "$1.propCount" "0"
    o.Set "$1.nextFileIndex" "0"
}

Channel.setObject(){ local ch="$1"; local obj="$2"; local parentName="${3:-}"
    o.ListProps "$obj"; local props=("$_r")
    for prop in "${props[@]}"; do
        o.Get "$obj.$prop"; local value="$_r"
        o.IsObject "$value"; local isObject="$_r"
        if [[ "$isObject" == "true" ]]; then
            #child object
            local newParentName="$prop"
            if [[ ! -z "$parentName" ]]; then
                newParentName="$parentName.$prop"
            fi
            Channel.setObject "$ch" "$value" "$newParentName"
        else
            local fullPropName="$prop"
            if [[ ! -z "$parentName" ]]; then
                fullPropName="$parentName.$prop"
            fi
            Channel.Set "$ch" "$fullPropName" "$value"
        fi
    done
};
#setts a property or a SHU struct, in the channel (to be send when Channel.Send is called)
Channel.Set(){ local ch="$1"; local prop="$2"; local value="$3"
    o.IsObject "$prop"; local isObject="$_r"
    if [[ "$isObject" == "true" ]]; then
        Channel.setObject "$ch" "$prop"
        return
    fi

    o.Get "$ch.propCount"; local count="$_r"
    o.Set "$ch.prop_$count""_name" "$prop"
    o.Set "$ch.prop_$count""_value" "$value"
    count=$((count+1))
    o.Set "$ch.propCount" "$count"

    o.Set "$ch.asmap_$prop" "$value"
}

#getts a property previously setted with Channel.Set
Channel.Get(){ local ch="$1"; local prop="$2"
    o.Get "$ch.asmap_$prop"
}


#waits for the next data to arrive in the channel
#If asObject is true, the result (_r) will be a SHU object with all properties set
Channel.WaitNext(){ local ch="$1"; local asObject="${2:-false}"
    o.Get "$ch._fname"; local fname="$_r"

    o.Get "$ch.nextFileIndex"; local index="$_r"
    fname="${fname}.$index"
    index=$((index+1))
    o.Set "$ch.nextFileIndex" "$index"

    while [ ! -f "$fname" ]; do
        sleep 0.1
    done

    o.Set "$ch.propCount" "0"
    #load the file content
    while IFS= read -r line; do
        #each line is in format: prop_name=prop_value
        local prop_name="${line%%=*}"
        local prop_value="${line#*=}"
        
        Channel.Set "$ch" "$prop_name" "$prop_value"
    done < "$fname"
    
    #delete the file to wait for the next data
    rm -f "$fname"

    if [[ "$asObject" == "true" ]]; then
        o.New ""; local obj="$_r"
        o.Get "$ch.propCount"; local count="$_r"
        for (( i=0; i<count; i++ )); do
            o.Get "$ch.prop_$i""_name"; local pname="$_r"
            o.Get "$ch.prop_$i""_value"; local pvalue="$_r"
            o.Set "$obj.$pname" "$pvalue"
        done
        _r="$obj"
    fi
}

#just a wrapper for Channel.WaitNext
Channel.Wait(){
    Channel.WaitNext "$@"
}

#sends all properties setted with Channel.Set to the channel
#also, unlocks one Channel.Wait call
Channel.Send(){ local ch="$1";
    o.Get "$ch._fname"; local fname="$_r"
    o.Get "$ch.nextFileIndex"; local index="$_r"
    fname="${fname}.$index"
    index=$((index+1))
    o.Set "$ch.nextFileIndex" "$index"

    o.Get "$ch.propCount"; local count="$_r"
    #write all properties to the file
    : > "$fname" #clear file
    for (( i=0; i<count; i++ )); do
        o.Get "$ch.prop_$i""_name"; local pname="$_r"
        o.Get "$ch.prop_$i""_value"; local pvalue="$_r"
        echo "${pname}=${pvalue}" >> "$fname"
    done
}
