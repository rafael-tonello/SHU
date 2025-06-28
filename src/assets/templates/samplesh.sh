#!/bin/bash
%miscplaceholder%

%fnameplaceholder%.main(){
    echo "arguments \"$@\""

    #create an object and associate '$%fnameplaceholder%' as it class name
    o.New "'$%fnameplaceholder%'"; local obj="$_r"

    #set some properties
    o.Set "$obj" "property" "value"
    o.Set "$obj.property2" "value2"

    #get a property (ClassName)
    o.Get "$obj.property"; local className="$_r"
    echo "Property value: $className"

    #call a method (first way)
    '$%fnameplaceholder%'.sampleMethod "$obj" "first" "way"

    #call a method (second way, using common)
    o.Call "$obj" "sampleMethod" "second" "calling" "way"

    #call a method (third way, using common)
    o.Call "$obj.sampleMethod" "third" "way"
}

%fnameplaceholder%.sampleMethod(){
    echo "arguments \"$@\""
}

%fnameplaceholder%.main "$@"