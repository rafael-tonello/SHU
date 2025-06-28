#!/bin/bash
thisScriptLocation="$(dirname "$(realpath "$BASH_SOURCE[0]")")"

source "$thisScriptLocation/../../../src/libs/common/tests.sh"
source "$thisScriptLocation/../../../src/libs/common/misc.sh"



# #basic object/stuct operations (allow basic OO oiperations in bash){

#     __o_count=0
#     o.New(){ local _className="$1"
#         _r="obj_$((__o_count++))_"
#         eval "$_r=obj"
#         o.Set "$_r" "ClassName" "$_className"
#     }


#     #resolve the last object name. Key could be informed with obj.<key> or via 'key' argument
#     #examples:
#     #   o.resolveFinalObjectAndKey "obj" "key" -> returns "name of obj" and "key"
#     #   o.resolveFinalObjectAndKey "obj.key" -> returns "name obj" and "key"
#     #   o.resolveFinalObjectAndKey "obj.other.childobject" "key" -> returns name of child object and "key"
#     #   o.resolveFinalObjectAndKey "obj" "other.childobject.key" -> returns name of child object and "key"
#     o.resolveFinalObjectAndKey(){
#     }

#     o.Set(){ local obj="$1"; local key="$2"; local value="${3:-"--empty--"}"
#     }

#     o.Get(){ local obj="$1"; local key="$2"
#     }

#     o._get(){ local obj="$1"; local key="$2"
#     }

#     o.Has(){ local obj="$1"; local key="$2"
#     }

#     o.HasMethod (){ local obj="$1"; local method="$2"
#     }

#     o.Delete(){ local obj="$1"; local key="$2"
#     }

#     o.ListProps(){ local obj="$1"
#     }

#     o.Destroy(){ local obj="$1"; local _destroyChildren="${2:-false}"
#     }

#     o.IsObject(){ local obj="$1"
#     }

#     o.Call(){ local obj="$1"; local method="$2"; 
#     }

#     o.Implements(){ local obj="$1"; local interface="$2"
#     }

#     o.Serialize(){ local obj="$1"; local serializer="$2"
#     }
#     o.ToString(){ o.Serialize "$@"; }

#     o.Deserialize(){ local obj="$1"; local serializer="$2"; local _parent="${3:-}"
#     }
#     o.FromString(){ o.Deserialize "$@"; return $?; }

#     o._serialize(){ local obj="$1"; local serializer="$2"; local _parent="${3:-}"
#     }

#     #ONKey comes from ObjectNotationKey
#     o._deserializeProp(){ local obj="$1"; local ONKey="$2"; local value="$3";
#     }

    Tests.BeginGroup "Misc Tests"
        Misc.Tests.TestObject(){
            Tests.BeginGroup "Object Tests"
                # Create a new object
                    o.New; local testObject="$_r"

                    Tests.BeginTest "Should not return error when creating a new object"
                    if [ ! -z "$_error" ]; then 
                        Tests.Fail "Object creation failed: $_error"; 
                    else
                        Tests.Success
                    fi

                    Tests.IsNotEmpty "$testObject" "Should return a valid object"

                # Set / Get a property
                    o.Set "$testObject" "name" "Test Object"
                    o.Get "$testObject" "name"; local name="$_r"
                    Tests.AreEquals "Test Object" "$name" "Should set the name property correctly"

                # Set / Get a property (using object notation)
                    o.Set "$testObject.name2" "Test Object"
                    o.Get "$testObject.name2"; local name="$_r"
                    Tests.AreEquals "Test Object" "$name" "Should set the name2 property correctly (using object notation)"

                # Check if the object has a property
                    o.Has "$testObject" "name"; local hasName="$_r"
                    Tests.IsTrue "$hasName" "Should have the name property"

                    o.Has "$testObject" "nonExistent"; local hasNonExistent="$_r"
                    Tests.IsFalse "$hasNonExistent" "Should not have a non-existent property"

                # Check if the object has a method
                    Class.SampleMethod(){ :; }
                    o.New "Class"; local classObject="$_r"
                    o.HasMethod "$classObject" "SampleMethod"; local hasMethod="$_r"
                    Tests.IsTrue "$hasMethod" "Should have the Get method"

                    o.HasMethod "$testObject" "NonExistentMethod"; local hasNonExistentMethod="$_r"
                    Tests.IsFalse "$hasNonExistentMethod" "Should not have a non-existent method"

                # Delete a property
                    o.Delete "$testObject" "name"; local deleteResult="$_r"
                    Tests.IsTrue "$deleteResult" "Should delete the name property"

                    o.Get "$testObject" "name"; local deletedName="$_r"
                    Tests.IsEmpty "$deletedName" "Should return empty for deleted property"

                #list properties
                    o.ListProps "$testObject"; local props=("${_r[@]}")
                    Tests.IsNotEmpty "$props" "Should list properties of the object"
                    
                    Tests.BeginTest "Should list 'name' property"
                    if [[ ! " ${props[@]} " =~ " name" ]]; then
                        Tests.Fail
                    else
                        Tests.Success
                    fi

                    Tests.BeginTest "Should list 'name2' property"
                    if [[ ! " ${props[@]} " =~ " name2" ]]; then
                        Tests.Fail
                    else
                        Tests.Success
                    fi
                
                # Destroy the object
                    o.Destroy "$testObject"; local destroyResult="$_r"
                    Tests.IsTrue "$destroyResult" "Should destroy the object"

                    o.Get "$testObject" "name"; local destroyedName="$_r"
                    Tests.IsEmpty "$destroyedName" "Should return empty for destroyed object"

                # Call a method
                    Class.Method(){
                        _r="Hello from Method"    
                    }
                    o.New "Class"; local classObject="$_r"
                    o.Call "$classObject" "Method"; local methodResult="$_r"
                    Tests.AreEquals "Hello from Method" "$methodResult" "Should call the method correctly"

                    #call using object notation
                    o.Call "$classObject.Method"; local methodResultON="$_r"
                    Tests.AreEquals "Hello from Method" "$methodResultON" "Should call the method correctly using object notation"

                # IsObject
                    o.IsObject "$testObject"; local isObject="$_r"
                    Tests.IsTrue "$isObject" "Should return true for a valid object"

                    o.IsObject "notAnObject"; local isNotObject="$_r"
                    Tests.IsFalse "$isNotObject" "Should return false for a non-object"

                # Implements
                    IClass.Method(){ :; }
                    IClass.Method2(){ :; }

                    NotImplClass.Method3(){ :; }

                    ImplClass.Method(){ :; }
                    ImplClass.Method2(){ :; }

                    o.New "ImplClass"; local implObject="$_r"
                    o.Implements "$implObject" "IClass"; local implResult="$_r"
                    Tests.IsTrue "$implResult" "Should implement the interface IClass"

                    o.New "NotImplClass"; local notImplObject="$_r"
                    o.Implements "$notImplObject" "IClass"; local notImplResult="$_r"
                    Tests.IsFalse "$notImplResult" "Should not implement the interface IClass"

                    o.New; local anonymousObject="$_r"
                    o.Implements "$anonymousObject" "IClass"; local anonymousImplResult="$_r"
                    Tests.IsFalse "$anonymousImplResult" "Should not implement the interface IClass for an anonymous object"
            Tests.EndGroup
        }; Misc.Tests.TestObject

    Tests.EndGroup
#}

if [ "$1" == "" ]; then
    Tests.Sumarize "$(misc.CreateHorizontalLine "=")"
fi
# 