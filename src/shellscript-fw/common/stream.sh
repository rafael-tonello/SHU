#!/bin/bash

#load companios library 'misc.sh' (It must have been charged by the user, but still tries)
thisscriptdir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$thisscriptdir/misc.sh"

#Stream.Sh
Stream.New(){
    o.New Stream; local streamId="$_r"
    o.New ""; listeners="$_r"
    o.Set "$streamId.Listeners" "$listeners"
    o.Set "$streamId.LastData" ""
    o.Set "$streamId.FirstDataAlreadySent" false

    _r="$streamId"
}

Stream.Listen(){ local stream="$1"; local callback="$2"
    o.Get "$stream.Listeners.Count"; local listenersCount="$_r"
    if [ "$listenersCount" == "" ]; then
        listenersCount=0
    fi
    o.Set "$stream.Listeners.Count" $((listenersCount + 1))
    o.Set "$stream.Listeners.Item_$listenersCount" "$callback"

    Stream.GetLast "$stream"; local lastData="$_r"
    if [ "$_error" == "" ]; then
        #call the callback with the last data
        eval "$callback \"$lastData\""
        #eval $callback "$lastData"
    fi

    _error=""
    return 0
};
Stream.Subscribe(){ Stream.Listen "$@"; }

Stream.Post(){ local stream="$1"; shift
    o.Get "$stream.Listeners.Count"; local listenersCount="$_r"
    if [ "$listenersCount" == "" ]; then
        listenersCount=0
    fi

    for ((i=0; i<listenersCount; i++)); do
        o.Get "$stream.Listeners.Item_$i"; local callback="$_r"
        if [ -n "$callback" ]; then
            #call the callback with the data
            eval "$callback \"$@\""
        fi
    done

    o.Set "$stream.LastData" "$1"
    o.Set "$stream.FirstDataAlreadySent" true
    _error=""
    return 0
}
Stream.Publish(){ Stream.Post "$@"; }
Stream.Write(){ Stream.Post "$@"; }

Stream.GetLast(){ local stream="$1"
    o.Get "$stream.FirstDataAlreadySent"; local firstDataAlreadySent="$_r"
    if [ "$firstDataAlreadySent" == "false" ]; then
        _error="No data has been posted to the stream yet."
        return 1
    fi

    o.Get "$stream.LastData";
    _error=""
    return 0
}
Stream.GetLastState(){ Stream.GetLast "$@"; }
