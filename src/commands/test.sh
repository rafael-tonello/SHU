#!/bin/bash

shu.Test(){
    shu_test_successCount=0;
    shu_test_failureCount=0;

    files=();
    folders=();

    recursive=false;
    for arg in "$@"; do
        if [[ "$arg" == "-r" || "$arg" == "--recursive" ]]; then
            recursive=true;
        elif [ -d "$arg" ]; then
            folders+=("$arg");
        elif [[ "$1" == *".test."* ]]; then
            files+=("$arg");
        else
            #check if the file exists
            if [ -f "$arg" ]; then
                local lastDotIndex=$(expr index "$1" .)
                local fName="${1:0:lastDotIndex-1}"
                local fExt="${1:lastDotIndex}"
                fName=$fName".test"$fExt
                if [ -f "$fName" ]; then
                    files+=("$fName");
                else
                    shu.printError "Test file for '$arg' ($fName) not found"
                fi 
            else
                shu.printError "tests for '$arg' not found"
            fi
        fi
    done

    #checkf no files and no folders were given
    if [ ${#files[@]} -eq 0 ] && [ ${#folders[@]} -eq 0 ]; then
        folders=("$PWD"); #use current directory as default
    fi

    for file in "${files[@]}"; do
        shu.runTestFile "$file"
        if [ "$_error" != "" ]; then
            shu.printError "Error running test file '$file': $_error"
            return 1
        
        fi
    done

    for folder in "${folders[@]}"; do
        shu.runFolderTests "$folder" "$recursive"
        if [ "$_error" != "" ]; then
            shu.printError "Error running tests in folder '$folder': $_error"
            return 1
        fi
    done

}

shu.runFolderTests(){ local directory="$1"; local _recursive=${2:-false}
    if [ ! -d "$directory" ]; then
        _error="Directory '$directory' not found."
        return 1
    fi

    #find all files with '*.test.*' in the given directory (not subdirectories)
    local testFiles=$(find "$directory" -maxdepth 1 -type f -name "*.test.*")

    for file in $testFiles; do
        shu.runTestFile "$file"
        if [ "$_error" != "" ]; then
            shu.printError "Error running test file '$file': $_error"
        fi
    done

    if [ "$_recursive" == "true" ]; then
        #find all subdirectories and run tests in them
        local subdirs=$(find "$directory" -type d)
        for subdir in $subdirs; do
            if [ "$subdir" != "$directory" ]; then
                shu.runFolderTests "$subdir" true
                if [ "$_error" != "" ]; then
                    shu.printError "Error running tests in folder '$subdir': $_error"
                fi
            fi
        done
    fi
}

shu.runTestFile(){ local file="$1"
    if [ ! -f "$file" ]; then
        _error="Test file '$file' not found."
        return 1
    fi

    #yellow message
    printf "\e[33m\n[Running testfile: '$file']\n\e[0m"
    #run the test file
    local retDir="$(pwd)"
    cd "$(dirname "$file")"
    if [ -d "/dev/shm" ]; then
        bash "$file" "calledbyshutests"
        export SHU_TESTS_success="$(cat /dev/shm/SHU_TESTS_success)"
        export SHU_TESTS_FAILURES="$(cat /dev/shm/SHU_TESTS_FAILURES)"
    else
        source "$file" "calledbyshutests"
    fi
    cd "$retDir"
    _error=""

    shu_test_successCount=$((shu_test_successCount + SHU_TESTS_success))
    shu_test_failureCount=$((shu_test_failureCount + SHU_TESTS_FAILURES))

}

shu.Test.Summary(){
    shu.CreateHorizontalLine "="
    echo "Tests summary:"
    echo "  Total tests: $((shu_test_successCount + shu_test_failureCount))"
    shu.printGreen "  Successful tests: $shu_test_successCount\n"
    shu.printRed "  Failed tests: $shu_test_failureCount\n"
    echo ""

    if [ "$shu_test_failureCount" -gt 0 ]; then
        echo "Some tests failed. Please check the output above for details."
    else
        echo "All tests passed successfully!"
    fi
    return $shu_test_failureCount
}

shu.Test.Help(){
    :;
}

if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help"  ]]; then
    shu.Test.Help
    return 0
fi


#check if arguments contaisn bashCompletion string
if [[ "$1" == "bashCompletion" ]]; then
    _r="";
    return 0
fi



shu.Test "$@"
shu.Test.Summary
return $?
