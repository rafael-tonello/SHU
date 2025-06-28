#!/bin/bash


shu.Tests(){
    shu_test_successCount=0;
    shu_test_failureCount=0;

    files=();
    folders=();

    local recursive=false;
    #if any argument is -r or --recursive, set recursive to true
    if [[ "$1" == *"--recursive"* ]] || [[ "$1" == *"-r"* ]]; then
        recursive=true
        #remove the --allow-subpackages or -asp from the arguments
        set -- "${@/--recursive/}"
        set -- "${@/-r/}"
    fi

    #if no args

    if [[ "$@" == "" ]]; then
        echo "No arguments provided. Running tests in the current directory."
        folders=("$PWD"); #use current directory as default
    fi

    for arg in "$@"; do
        if  [ "$arg" == "" ]; then
            continue; #skip empty arguments
        fi
        if [ -d "$arg" ]; then
            folders+=("$arg");
        elif [[ "$1" == *".test"* ]]; then
            echo "Founde filete"
            files+=("$arg");
        else
            #check if the file exists
            if [ -f "$arg" ]; then
                local fExtension="${arg##*.}"
                local fName="${arg%.*}"                
                fName=$fName".tests."$fExtension
                if [ -f "$fName" ]; then
                    files+=("$fName");
                else
                    shu.printError "Tests fil for '$arg' ($fName) not found"
                fi 
            else
                shu.printError "tests for '$arg' not found"
            fi
        fi
    done

    for file in "${files[@]}"; do
        shu.runTestFile "$file"
        if [ "$_error" != "" ]; then
            shu.printError "Error running tests file '$file': $_error"
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

    #find all files with '*.tests.*' in the given directory (not subdirectories)
    local testFiles=$(find "$directory" -maxdepth 1 -type f -name "*.test*")

    for file in $testFiles; do
        shu.runTestFile "$file"
        if [ "$_error" != "" ]; then
            shu.printError "Error running tests file '$file': $_error"
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
    echo "run test file '$file'"
    if [ ! -f "$file" ]; then
        _error="Tests file '$file' not found."
        return 1
    fi

    #yellow message
    printf "\e[33m\n[Running testfile: '$file']\n\e[0m"
    #run the tests file
    if [ -d "/dev/shm" ]; then
        bash "$file" "calledbyshutests"
        export SHU_TESTS_success="$(cat /dev/shm/SHU_TESTS_success)"
        export SHU_TESTS_FAILURES="$(cat /dev/shm/SHU_TESTS_FAILURES)"
    else
        source "$file" "calledbyshutests"
    fi
    _error=""

    shu_test_successCount=$((shu_test_successCount + SHU_TESTS_success))
    shu_test_failureCount=$((shu_test_failureCount + SHU_TESTS_FAILURES))

}

shu.Tests.Summary(){
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

shu.Tests.Help(){    
    echo "tests [what] [options]    - Finds tests files and runs them. Tests files are files with the '.tests' sequence in its name. If you provide a file without '.tests', shu will try to find it by putting '.tests.' between filename and its extension. If nothing was provided (no arguments), shu will assume the current folder as directory."
    echo "  what                     - You can specify a filename or a directory. Using a file name, it will runs only the specified tests file. Using a direcotry, it will run all tests files in the directory"
    echo "  options:"
    echo "   --recursive, -r           - If you provide a directory, shu will run tests in all subdirectories recursively."
}

if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help"  ]]; then
    shu.Tests.Help
    return 0
fi


#check if arguments contaisn bashCompletion string
if [[ "$1" == "bashCompletion" ]]; then
    _r="";
    return 0
fi

shu.Tests "$@"
shu.Tests.Summary
return $?
