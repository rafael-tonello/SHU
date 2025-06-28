#!/usr/bin/env bash
testScriptLocation="$(dirname "$(realpath "$BASH_SOURCE[0]")")"
source "$testScriptLocation/../../../src/libs/common/tests.sh"
source "$testScriptLocation/../../../src/libs/common/misc.sh"
source "$testScriptLocation/../../../src/libs/serializers/jsonserializer.sh"

Tests.BeginGroup "JsonSerializer Tests"
    o.New; obj="$_r"

    o.Set "$obj" property1 "value1" "$obj"
    o.Set "$obj" property2 "value2" "$obj"
    o.Set "$obj" property3 "value3" "$obj"
    echo "------------------------------------------------------"
    o.Set "$obj.childee.child2.child3.child3value" "oooooooooooooooooooooooo"
    echo "------------------------------------------------------"

    o.New; obj2="$_r"
    o.Set "$obj2" otherprop1 "aa1" "$obj2"
    o.Set "$obj2" otherprop2 "aa2" "$obj2"
    o.Set "$obj2" otherprop3 "aa3" "$obj2"
    o.Set "$obj" child "$obj2"


    JsonSerializer.New; serializer="$_r"
    if [ ! -z "$_error" ]; then
        Tests.Fail "JsonSerializer.New failed: $_error"
    else
        Tests.Pass
    fi

    o.Serialize "$obj" "$serializer"
    echo "$_r"
    if [ ! -z "$_error" ]; then
        Tests.Fail "JsonSerializer.New failed: $_error"
    else
        Tests.Pass "JsonSerializer.New succeeded"
    fi

    
Tests.EndGroup