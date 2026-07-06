#!/bin/bash

if [ "$SHU_TESTS_LOADED" == "true" ]; then
    #return if sources
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 1
    fi
    exit 1
fi

SHU_TESTS_LOADED="true"

Tests_currGroupLevel=0
Tests_suecessCount=0
Tests_failureCount=0
Test_identText="  "
Tests_registeredTests=()

Tests_lastTestEnded=false

if [ "$SHU_MISC_LOADED" != "true" ]; then
    #red message
    printf "\033[31mError: This library requires the 'misc.sh' library to be loaded first. Please load it before loading this library.\033[0m\n"

    #return if sources
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 1
    fi
    exit 1
fi


#create a idented tests session
Tests.BeginGroup(){ local groupTitle="$1"
    Tests.printGroupTitle "$groupTitle"
    Tests_currGroupLevel=$((Tests_currGroupLevel + 1))
}

# End the current group of tests (decrease the group level. Decreases the identation)
Tests.EndGroup(){
    Tests_currGroupLevel=$((Tests_currGroupLevel - 1))
}

#
Tests.printGroupTitle(){ local groupTitle="$1"
    Tests.printIdentation
    misc.PrintYellow "$groupTitle\n"
}

#begins a test (use to print a message like 'should do something')
Tests.BeginTest(){ local testTitle="$1"
    Tests_lastTestEnded=false
    Tests.printIdentation
    printf "$testTitle... "
}

_tests_yellow_prefix="\033[33m"
_tests_green_prefix="\033[32m"
_tests_red_prefix="\033[31m"
_tests_blue_prefix="\033[34m"
_tests_cyan_prefix="\033[36m"
_tests_white_prefix="\033[37m"
_tests_magenta_prefix="\033[35m"
_tests_gray_prefix="\033[90m"

#Use it to print a message while running a test. You can use it, for example, to print a command output.
#You can use the _linePrefix argument to add a fix text (like a marker, or event a identation text with spaces)
#to all lines of $text.
#Also, you can use the _suffix argument to add a text at the end of each line.
Tests.PrintLine() {
    local text="$1"
    local _linePrefix="${2:-}"
    local _suffix="${3:-}"
    local _color=_tests_"${4:=gray}"_prefix

    while IFS= read -r line; do
        Tests.printIdentation
        printf "${_color}${_linePrefix}${line}${_suffix}\033[0m\n"
        Tests.PrintGray "${_linePrefix}${line}${_suffix}\n"
    done <<< "$text"
}

#If you want to print a file, you can use this function. It is very similar to Tests.PrintLine, but it reads the file line by line.
Tests.PrintFile() {
    local filePath="$1"
    local _linePrefix="${2:-}"
    local _suffix="${3:-}"

    if [ ! -f "$filePath" ]; then
        Tests.PrintRed "File not found: $filePath\n"
        return 1
    fi

    while IFS= read -r line; do
        Tests.printIdentation
        Tests.PrintGray "${_linePrefix}${line}${_suffix}\n"
    done < "$filePath"
}

Tests.printIdentation(){
    local i=0
    while [ $i -lt $Tests_currGroupLevel ]; do
        echo -n "$Test_identText"
        i=$((i + 1))
    done
}

#Sinalizes the end of a test. You must inform the test result (true for success, false for failure) in the first argument.
#The second argument is optional and you can use it to provide additional information about the test result.
#This is the function that, in fact, contabilizes the test results.
Tests.EndTest(){ local success="$1"; local _aditionalInfo="${2:-}"
    Tests_lastTestEnded=true

    if [ "$success" = "true" ]; then
        misc.PrintGreen "success"
        Tests_suecessCount=$((Tests_suecessCount + 1))
        if [ -n "$_aditionalInfo" ]; then
            misc.PrintGreen ": ($_aditionalInfo)"
        fi
    else
        misc.PrintRed "failed"
        Tests_failureCount=$((Tests_failureCount + 1))
        if [ -n "$_aditionalInfo" ]; then
            misc.PrintRed ": ($_aditionalInfo)"
        fi
    fi
    printf "\n"

    

    #additionally, sets files SHU_TESTS_success and SHU_TESTS_FAILURES inside /dev/shm
    if [ -d "/dev/shm" ]; then
        echo "$Tests_suecessCount" > "/dev/shm/SHU_TESTS_success"
        echo "$Tests_failureCount" > "/dev/shm/SHU_TESTS_FAILURES"
    else
        #export tests results (to allow integration with 'shu test' command. Test files will be sourced by shu if /dev/shm is not available
        export SHU_TESTS_success="$Tests_suecessCount"
        export SHU_TESTS_FAILURES="$Tests_failureCount"
    fi
}

Tests.Fail(){ local _aditionalInfo="${1:-"Test failed"}"
    Tests.EndTest false "$_aditionalInfo"
}

Tests.Success(){ local _aditionalInfo="${1:-}"
    Tests.EndTest true "$_aditionalInfo"
}

Tests.Pass(){ Tests.Success "$@"; return $?; }


#print a summary of the tests results
#This function uses _r and the default bash function return value to return the number of failed tests.
Tests.PrintSummary(){ local _header=${1:-tests summary:}; local _footer=${2:-}
    printf "\n$_header\n"
    misc.PrintGreen "  Success: $Tests_suecessCount\n"
    misc.PrintRed "  Failures: $Tests_failureCount\n"
    printf "\n"
    if [ $Tests_failureCount -eq 0 ]; then
        misc.PrintGreen "All tests passed!\n"
    else
        misc.PrintRed "Some tests failed!\n"
    fi
    printf "$_footer\n"

    _r="$Tests_failureCount"
    return $Tests_failureCount
}; Tests.Sumarize(){ Tests.PrintSummary "$@"; return $?; }


#a function that cals Tests.BeginTest, testes if the args expected ($1) and actual ($2) are equals and calls Tests.EndTest with the result.
Assert.Equals(){
    local expected="$1"
    local actual="$2"
    local title="${3:-"Value should be equals to '$expected'"}"

    Tests.BeginTest "$title"
    if [ "$expected" == "$actual" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected '$expected', got '$actual'"
        return 1
    fi
}; 
Assert.Is(){
    Assert.Equals "$@"
    return $?
}

Assert.NotEquals(){
    local expected="$1"
    local actual="$2"
    local title="${3:-"Value should not be equals to '$expected'"}"

    Tests.BeginTest "$title"
    if [ "$expected" != "$actual" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected not equals to '$expected', got '$actual'"
        return 1
    fi
}

Assert.IsNot(){
    Assert.NotEquals "$@"
    return $?
}

Assert.GreaterThan(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be greater than '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -gt "$threshold" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected greater than '$threshold', got '$value'"
        return 1
    fi
}

Assert.LessThan(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be less than '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -lt "$threshold" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected less than '$threshold', got '$value'"
        return 1
    fi
}

Assert.GreaterThanOrEquals(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be greater than or equals to '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -ge "$threshold" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected greater than or equals to '$threshold', got '$value'"
        return 1
    fi
}

Assert.LessThanOrEquals(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be less than or equals to '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -le "$threshold" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected less than or equals to '$threshold', got '$value'"
        return 1
    fi
}

#min and max are inclusive
Assert.Between(){
    local value="$1"
    local min="$2"
    local max="$3"
    local title="${4:-"Value should be between '$min' and '$max'"}"

    Tests.BeginTest "$title"
    if [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected between '$min' and '$max', got '$value'"
        return 1
    fi
}

#min and max are not inclusive
Assert.NotBetween(){
    local value="$1"
    local min="$2"
    local max="$3"
    local title="${4:-"Value should not be between '$min' and '$max'"}"

    Tests.BeginTest "$title"
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected not between '$min' and '$max', got '$value'"
        return 1
    fi
}

Assert.BeginsWith(){
    local value="$1"
    local prefix="$2"
    local title="${3:-"Value should begin with '$prefix'"}"

    Tests.BeginTest "$title"
    if [[ "$value" == "$prefix"* ]]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected to begin with '$prefix', got '$value'"
        return 1
    fi
}

Assert.EndsWith(){
    local value="$1"
    local suffix="$2"
    local title="${3:-"Value should end with '$suffix'"}"

    Tests.BeginTest "$title"
    if [[ "$value" == *"$suffix" ]]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected to end with '$suffix', got '$value'"
        return 1
    fi
}

Assert.Contains(){
    local value="$1"
    local substring="$2"
    local title="${3:-"Value should contain '$substring'"}"

    Tests.BeginTest "$title"
    if [[ "$value" == *"$substring"* ]]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected to contain '$substring', got '$value'"
        return 1
    fi
}

Assert.IsTrue(){
    local value="$1"
    local title="${2:-"Value should be true"}"

    Tests.BeginTest "$title"
    if [ "$value" == "true" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected true, got '$value'"
        return 1
    fi
}

Assert.IsFalse(){
    local value="$1"
    local title="${2:-"Value should be false"}"

    Tests.BeginTest "$title"
    if [ "$value" == "false" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected false, got '$value'"
        return 1
    fi
}

Assert.IsEmpty(){
    local value="$1"
    local title="${2:-"Value should be empty"}"

    Tests.BeginTest "$title"
    if [ -z "$value" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected empty, got '$value'"
        return 1
    fi
}

Assert.IsNotEmpty(){
    local value="$1"
    local title="${2:-"Value should not be empty"}"

    Tests.BeginTest "$title"
    if [ -n "$value" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Expected not empty, got '$value'"
        return 1
    fi
}

Assert.FileExists(){
    local filePath="$1"
    local title="${2:-"File should exist at '$filePath'"}"

    Tests.BeginTest "$title"
    if [ -f "$filePath" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "File not found: '$filePath'"
        return 1
    fi
}

Assert.FileNotExists(){
    local filePath="$1"
    local title="${2:-"File should not exist at '$filePath'"}"

    Tests.BeginTest "$title"
    if [ ! -f "$filePath" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "File found when it should not: '$filePath'"
        return 1
    fi
}

Assert.DirExists(){
    local dirPath="$1"
    local title="${2:-"Directory should exist at '$dirPath'"}"

    Tests.BeginTest "$title"
    if [ -d "$dirPath" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Directory not found: '$dirPath'"
        return 1
    fi
}

Assert.DirNotExists(){
    local dirPath="$1"
    local title="${2:-"Directory should not exist at '$dirPath'"}"

    Tests.BeginTest "$title"
    if [ ! -d "$dirPath" ]; then
        Tests.EndTest true
        return 0
    else
        Tests.EndTest false "Directory found when it should not: '$dirPath'"
        return 1
    fi
}


#helpers

#instead calls for BeginTest + EndTest, you can register a test function and its description using this function. Also, you can use _error to return a message in case of failure or _r in case of success. 
Tests.Register(){ local callback="$1"; local _title="${2:-}"; 
    Tests_registeredTests+=("$_title|$callback")
}


#if title is provided, BeginTest will be called to print the title.
#if EndTest is nof called (by calling EndTest itself, of Assert.* functions), the function result code wil be used do call EndTest and register at lest one test result.
Tests.RunRegistered(){
    for test in "${Tests_registeredTests[@]}"; do
        local title="${test%%|*}"
        local callback="${test##*|}"


        if [ -z "$callback" ]; then
            Tests.EndTest false "No callback function provided for test: $title"
            continue
        fi

        if ! declare -f "$callback" > /dev/null; then
            Tests.EndTest false "Callback function '$callback' not found for test: $title"
            continue
        fi
        if [ -n "$title" ]; then
            Tests.BeginGroup "$title"
        fi
        Tests_lastTestEnded=false
        unset _r
        unset _error
        $callback; local result=$?

        #check if user call Tests.EndTest inside the callback function. If not, we call it here.
        if [ "$Tests_lastTestEnded" = false ]; then
            Tests.BeginTest "No assert/EndTest function used. Function result code should be 0... "
            if [ $result -eq 0 ]; then
                Tests.EndTest true "$_r"
            else
                Tests.EndTest false "$_error"
            fi
        fi

        if [ "$result" -ne 0 ]; then
            #register a failed test
            Tests.EndTest false "$Callback function did not return 0. Result code: $result"
        fi

        Tests.EndGroup
    done

    Tests.PrintSummary "Registered tests summary:"
    return $?
}

Tests._findAndTestFiles(){ local _curFolder="${1:-.}"
    #scroll files ending with .test.sh and source them to run the tests
    for file in "$_curFolder"/*; do
        if [ -d "$file" ] && [[ "$file" != *".git"* ]]; then
            Tests._findAndTestFiles "$file"
        elif [ -f "$file" ] && [[ "$file" == *.test.sh ]]; then
            misc.PrintBlue "Running tests in file: $(basename "$file")\n"

            local returnTo="$(pwd)"
            cd "$_curFolder"
            #source "$file"; local retCode=$?
            bash -c "source \"$file\"; retCode=\$?; echo \$Tests_suecessCount >/tmp/SHU_TESTS_success; echo \$Tests_failureCount >/tmp/SHU_TESTS_FAILURES; echo \$retCode > /tmp/SHU_TESTS_RETCODE; exit \$retCode"

            local tmpFailures=$(cat /tmp/SHU_TESTS_FAILURES 2>/dev/null)
            local tmpSuccess=$(cat /tmp/SHU_TESTS_success 2>/dev/null)
            local retCode=$(cat /tmp/SHU_TESTS_RETCODE 2>/dev/null)

            #if no tests were run (detected, using this library), uses the retcode
            if [ "$tmpFailures" == "" ] && [ "$tmpSuccess" == "" ]; then
                tmpFailures=0
                tmpSuccess=0
                if [ "$retCode" -eq 0 ]; then
                    tmpSuccess=1
                else
                    tmpFailures=1
                fi
            fi

            cd "$returnTo"

            Tests_suecessCount=$((Tests_suecessCount + tmpSuccess))
            Tests_failureCount=$((Tests_failureCount + tmpFailures))
        fi
    done  
}


# function to be used directly in the command line {
    #source misc.sh; source tests.sh; Tests.FindAndRunTestFiles [folder]
    Tests.FindAndRunTestFiles(){
        Tests._findAndTestFiles "${1:-"./"}"

        local lastFolderName=$(basename "$1")

        misc.CreateHorizontalLine "[ Result for tests in folder '$lastFolderName' ]" "=" false
        misc.PrintBrightCyan "$_r"
        Tests.PrintSummary "Tests summary for folder '$lastFolderName':"
        return $?
    }
# }
