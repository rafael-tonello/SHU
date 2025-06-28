#!/bin/bash
Tests_currGroupLevel=0
Tests_suecessCount=0
Tests_failureCount=0
Test_identText="  "

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
    Tests.PrintYellow "Group: $groupTitle\n"
}

#begins a test (use to print a message like 'should do something')
Tests.BeginTest(){ local testTitle="$1"
    Tests.printIdentation
    printf "$testTitle ..."
}

#Use it to print a message while running a test. You can use it, for example, to print a command output.
#You can use the _linePrefix argument to add a fix text (like a marker, or event a identation text with spaces)
#to all lines of $text.
#Also, you can use the _suffix argument to add a text at the end of each line.
Tests.PrintText() {
    local text="$1"
    local _linePrefix="${2:-}"
    local _suffix="${3:-}"

    while IFS= read -r line; do
        Tests.printIdentation
        Tests.PrintGray "${_linePrefix}${line}${_suffix}\n"
    done <<< "$text"
}

#If you want to print a file, you can use this function. It is very similar to Tests.PrintText, but it reads the file line by line.
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
    if [ "$success" = "true" ]; then
        Tests.PrintGreen "success"
        Tests_suecessCount=$((Tests_suecessCount + 1))
        if [ -n "$_aditionalInfo" ]; then
            Tests.PrintGreen ": ($_aditionalInfo)"
        fi
    else
        Tests.PrintRed "failed"
        Tests_failureCount=$((Tests_failureCount + 1))
        if [ -n "$_aditionalInfo" ]; then
            Tests.PrintRed ": ($_aditionalInfo)"
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
Tests.PrintSummary(){ local _header=${1:-}; local _footer=${2:-}
    printf "\n$_header\nTests summary:\n"
    Tests.PrintGreen "  Success: $Tests_suecessCount\n"
    Tests.PrintRed "  Failures: $Tests_failureCount\n"
    printf "\n"
    if [ $Tests_failureCount -eq 0 ]; then
        Tests.PrintGreen "All tests passed!\n"
    else
        Tests.PrintRed "Some tests failed!\n"
    fi
    printf "$_footer\n"

    _r="$Tests_failureCount"
    return $Tests_failureCount
}; Tests.Sumarize(){ Tests.PrintSummary "$@"; return $?; }

Tests.PrintYellow(){
    printf "\033[33m$1\033[0m"
}
Tests.PrintGreen(){
    printf "\033[32m$1\033[0m"
}
Tests.PrintRed(){
    printf "\033[31m$1\033[0m"
}
Tests.PrintBlue(){
    printf "\033[34m$1\033[0m"
}
Tests.PrintCyan(){
    printf "\033[36m$1\033[0m"
}
Tests.PrintWhite(){
    printf "\033[37m$1\033[0m"
}
Tests.PrintMagenta(){
    printf "\033[35m$1\033[0m"
}
Tests.PrintGray(){
    printf "\033[90m$1\033[0m"
}


#a function that cals Tests.BeginTest, testes if the args expected ($1) and actual ($2) are equals and calls Tests.EndTest with the result.
Tests.AreEquals(){
    local expected="$1"
    local actual="$2"
    local title="${3:-"Value should be equals to '$expected'"}"

    Tests.BeginTest "$title"
    if [ "$expected" == "$actual" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected '$expected', got '$actual'"
    fi
}

Tests.AreNotEquals(){
    local expected="$1"
    local actual="$2"
    local title="${3:-"Value should not be equals to '$expected'"}"

    Tests.BeginTest "$title"
    if [ "$expected" != "$actual" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected not equals to '$expected', got '$actual'"
    fi
}

Tests.IsGreaterThan(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be greater than '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -gt "$threshold" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected greater than '$threshold', got '$value'"
    fi
}

Tests.IsLessThan(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be less than '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -lt "$threshold" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected less than '$threshold', got '$value'"
    fi
}

Tests.IsGreaterThanOrEquals(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be greater than or equals to '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -ge "$threshold" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected greater than or equals to '$threshold', got '$value'"
    fi
}

Tests.IsLessThanOrEquals(){
    local value="$1"
    local threshold="$2"
    local title="${3:-"Value should be less than or equals to '$threshold'"}"

    Tests.BeginTest "$title"
    if [ "$value" -le "$threshold" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected less than or equals to '$threshold', got '$value'"
    fi
}

#min and max are inclusive
Tests.IsBetween(){
    local value="$1"
    local min="$2"
    local max="$3"
    local title="${4:-"Value should be between '$min' and '$max'"}"

    Tests.BeginTest "$title"
    if [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected between '$min' and '$max', got '$value'"
    fi
}

#min and max are not inclusive
Tests.IsNotBetween(){
    local value="$1"
    local min="$2"
    local max="$3"
    local title="${4:-"Value should not be between '$min' and '$max'"}"

    Tests.BeginTest "$title"
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected not between '$min' and '$max', got '$value'"
    fi
}

Tests.BeginsWith(){
    local value="$1"
    local prefix="$2"
    local title="${3:-"Value should begin with '$prefix'"}"

    Tests.BeginTest "$title"
    if [[ "$value" == "$prefix"* ]]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected to begin with '$prefix', got '$value'"
    fi
}

Tests.EndsWith(){
    local value="$1"
    local suffix="$2"
    local title="${3:-"Value should end with '$suffix'"}"

    Tests.BeginTest "$title"
    if [[ "$value" == *"$suffix" ]]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected to end with '$suffix', got '$value'"
    fi
}

Tests.Contains(){
    local value="$1"
    local substring="$2"
    local title="${3:-"Value should contain '$substring'"}"

    Tests.BeginTest "$title"
    if [[ "$value" == *"$substring"* ]]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected to contain '$substring', got '$value'"
    fi
}

Tests.IsTrue(){
    local value="$1"
    local title="${2:-"Value should be true"}"

    Tests.BeginTest "$title"
    if [ "$value" == "true" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected true, got '$value'"
    fi
}

Tests.IsTrue_Eval(){
    local test="$1"
    local title="${2:-"Value should be true"}"

    Tests.BeginTest "$title"
    eval 'if [ $test ]; then
                Tests.EndTest true
            else
                Tests.EndTest false "Expected true, got '"'"$value"'"'"
            fi
    '
}

Tests.IsFalse(){
    local value="$1"
    local title="${2:-"Value should be false"}"

    Tests.BeginTest "$title"
    if [ "$value" == "false" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected false, got '$value'"
    fi
}

Tests.IsFalse_Eval(){
    local test="$1"
    local title="${2:-"Value should be false"}"

    Tests.BeginTest "$title"
    eval 'if [ ! $test ]; then
                Tests.EndTest true
            else
                Tests.EndTest false "Expected false, got '"'"$value"'"'"
            fi
    '
}

Tests.IsEmpty(){
    local value="$1"
    local title="${2:-"Value should be empty"}"

    Tests.BeginTest "$title"
    if [ -z "$value" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected empty, got '$value'"
    fi
}

Tests.IsNotEmpty(){
    local value="$1"
    local title="${2:-"Value should not be empty"}"

    Tests.BeginTest "$title"
    if [ -n "$value" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Expected not empty, got '$value'"
    fi
}

Tests.FileExists(){
    local filePath="$1"
    local title="${2:-"File should exist at '$filePath'"}"

    Tests.BeginTest "$title"
    if [ -f "$filePath" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "File not found: '$filePath'"
    fi
}

Tests.FileNotExists(){
    local filePath="$1"
    local title="${2:-"File should not exist at '$filePath'"}"

    Tests.BeginTest "$title"
    if [ ! -f "$filePath" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "File found when it should not: '$filePath'"
    fi
}

Tests.DirExists(){
    local dirPath="$1"
    local title="${2:-"Directory should exist at '$dirPath'"}"

    Tests.BeginTest "$title"
    if [ -d "$dirPath" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Directory not found: '$dirPath'"
    fi
}

Tests.DirNotExists(){
    local dirPath="$1"
    local title="${2:-"Directory should not exist at '$dirPath'"}"

    Tests.BeginTest "$title"
    if [ ! -d "$dirPath" ]; then
        Tests.EndTest true
    else
        Tests.EndTest false "Directory found when it should not: '$dirPath'"
    fi
}

