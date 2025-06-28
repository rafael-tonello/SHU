#!/bin/bash
thisScriptLocation="$(dirname "$(realpath "$BASH_SOURCE[0]")")"

source "$thisScriptLocation/../../../src/libs/common/tests.sh"
source "$thisScriptLocation/../../../src/libs/common/stream.sh"

Stream.Tests.Main(){
    Tests.BeginGroup "Stream Tests"
    Stream.New; local stream="$_r"

    Tests.IsNotEmpty "$stream" "Should return a valid stream object"

    
    Stream.Post "$stream" "Hello, World!"
    o.Call "$stream.GetLast"; local lastData="$_r"

    Tests.AreEquals "Hello, World!" "$lastData" "Post should set lastData"

    glbl_received=""
    o.Call "$stream.Listen" '__f(){
        glbl_received="$1"
    }; __f';

    o.Call "$stream.Post" "Test Data"
    
    Tests.AreEquals "Test Data" "$glbl_received" "Listen should receive the last data posted"

}; Stream.Tests.Main

