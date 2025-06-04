#!/bin/bash
#setup {
    #cp ./shu-cli.sh /tmp/
    #shucmd="/tmp/shu-cli.sh"
    thisScriptLocation=$(dirname "$(readlink -f "$0")")
    shucmd="$thisScriptLocation/shu-cli.sh"
    chmod +x "$shucmd"

    tempDir="/tmp/shu-cli-test"
    eraseTempFolderAfterTests=true
    #tempDir="./tmp"
    #eraseTempFolderAfterTests=false

    mainDir=$(pwd)
    rm -rf "$tempDir"
#}

#Note: All Calls to 'shu' are with stdout and stderr supressed.

#functions for printing tests and auxiliary functions {
    sucess=0
    failure=0

    startTest() {
        printf "    $@ ..."
    }
    
    sucess() {
        sucess=$((sucess + 1))
        if [ -z "$1" ]; then
            printf "\033[0;32m sucess\033[0m\n"
        else
            printf "\033[0;32m sucess: $1\033[0m\n"
        fi
    }

    failure() {
        failure=$((failure + 1))
        printf "\033[0;31m failed: $1\033[0m\n"
    }

    printSession() {
        printf "\033[0;33m%s\033[0m\n" "$1"
    }

    printResume(){
        echo ""
        echo "------------------------[ tests summary ]------------------------"
        echo "Total tests: $((sucess + failure))"
        echo "Successful tests: $sucess"
        echo "Failed tests: $failure"

        return $failure
    }

# }

#shu init tests {
    printSession "Testing shu init"
    test_shu_init_withNoProjectName(){
        cd "$mainDir"
        startTest "Should use folder name if no project name is given"
        local tmpdir="$tempDir$(mktemp -u)_init_with_no_name"
        mkdir -p "$tmpdir"
        cd "$tmpdir"
        
        "$shucmd" init > /dev/null

        if [ -f "./shu.yaml" ]; then
            sucess
        else
            failure "shu init (with no name) failed. File shu.yaml was not created."
        fi
        cd "$mainDir"
    }; test_shu_init_withNoProjectName
    
    test_shu_int(){
        cd "$mainDir"
        startTest "Should create a shu.yaml file with the given project name"
        local tmpdir="$tempDir$(mktemp -u)_init_with_name"

        mkdir -p "$tmpdir"
        cd "$tmpdir"

        "$shucmd" init "test-project" > /dev/null

        if [ -f "./shu.yaml" ]; then
            sucess
        else
            failure "shu init (with name) did not create .shu.yaml file."
        fi

        #check if the file contains the project name (user yq to get .Should clone the repository, checkout to the tag and get the subfoldername property)
        startTest "Should write the project name to the shu.yaml file"
        if yq ".name" "./shu.yaml" | grep -q "test-project"; then
            sucess
        else
            failure "Test failed: .shu.yaml does not contain the correct project name."
        fi
        cd "$mainDir"
    }; test_shu_int
# }

#shu setmain tests {
    printSession "Testing shu setmain"
    test_shu_setmain(){
        cd "$mainDir"
        
        local tmpdir="$tempDir$(mktemp -u)_setmain"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        echo "#!/bin/sh" > "./main.sh"
        echo "echo 'This is the main script'" >> "./main.sh"
        echo "" >> "./main.sh"

        cp main.sh main2.sh

        chmod +x "./main.sh"
        chmod +x "./main2.sh"

        #set main
        "$shucmd" mainfile add "main.sh" > /dev/null
        "$shucmd" mainfile add "main2.sh" > /dev/null


        #check if the "main.sh" file was added to the 'main' list of the shu.yaml file
        startTest "Setmain should the scriptname to the shu.yaml file"
        if yq ".main" "./shu.yaml" | grep -q "main.sh"; then
            sucess
        else
            failure "shu setmain failed to set the main script."
        fi

        #check if the main2.sh file was not added to the 'main' list of the shu.yaml file
        #if yq eval ".\"$key\"[]" "$file" | grep -Fxq "$value"; then
        startTest "Setmain should add the second script to the main list"
        if yq eval ".\"main\"[]" "./shu.yaml" | grep "main2.sh" > /dev/null; then
            sucess
        else
            failure "shu setmain incorrectly added main2.sh to the main list."
        fi

        cd "$mainDir"
    }; test_shu_setmain
#}

#shu get tests {
    printSession "Testing shu get"

    createFakeGitRepo() { local description="${1:-}";
        local currDir=$(pwd)
        local tmpdir="$tempDir/fakeRepos$(mktemp -u)_$description"
        mkdir -p "$tmpdir"
        cd "$tmpdir"
        git init > /dev/null 2>&1

        local realTmpDirPath=$(pwd)
        local completeTmpDitPah=$(realpath "$realTmpDirPath")
        git config --global --add safe.directory "$completeTmpDitPah"
        git config --global --add safe.directory "$completeTmpDitPah/.git"

        git config user.name "Test User"
        git config user.email "testuser@email.com"

        echo "This is a test file" > test.txt
        git add test.txt > /dev/null 2>&1
        git commit -m "Initial commit" > /dev/null 2>&1

        _r=$(pwd)
        cd "$currDir"
    }

    test_shu_get(){
        cd "$mainDir"
        createFakeGitRepo "firstTest_repo1"; local repo="$_r"
        createFakeGitRepo "firstTest_repo2"; local repo2="$_r"
        createFakeGitRepo "firstTest_repo3"; local repo3="$_r"
        

        local tmpdir="$tempDir$(mktemp -u)_get"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        
        #init project
        "$shucmd" init "test-project" > /dev/null
        

        #call shu get
        "$shucmd" get "$repo" > /dev/null
        "$shucmd" get "$repo2" > /dev/null
        "$shucmd" get "$repo3" > /dev/null
        local repoBasename=$(basename "$repo")
        local repoBasename2=$(basename "$repo2")
        local repoBasename3=$(basename "$repo3")

        startTest "Should create the first repository directory"
        if [ -d "./.shu/packages/$repoBasename" ]; then
            sucess
        else
            failure "'shu get' failed to clone the repository."
        fi

        startTest "Should create a second repository directory"
        if [ -d "./.shu/packages/$repoBasename2" ]; then
            sucess
        else
            failure "'shu get' failed to clone the second repository."
        fi

        startTest "Should create a third repository directory"
        if [ -d "./.shu/packages/$repoBasename3" ]; then
            sucess
        else
            failure "'shu get' failed to clone the third repository."
        fi

        startTest "Should add the first repository to the shu.yaml file"
        #check if the repository was added to the shu.yaml file
        if yq ".deps" "./shu.yaml" | grep -q "$repoBasename"; then
            sucess
        else
            failure "shu get did not add the first repository to the shu.yaml file."
        fi

        startTest "Should add the second repository to the shu.yaml file"
        if yq ".deps" "./shu.yaml" | grep -q "$repoBasename2"; then
            sucess
        else
            failure "shu get did not add the second repository to the shu.yaml file."
        fi

        startTest "Should add the third repository to the shu.yaml file"
        if yq ".deps" "./shu.yaml" | grep -q "$repoBasename2"; then
            sucess
        else
            failure "shu get did not add the third repository to the shu.yaml file."
        fi
        
        cd "$mainDir"
    }; test_shu_get

    test_get_repo_with_invalid_url(){
        cd "$mainDir"
        
        local tmpdir="$tempDir$(mktemp -u)_get_invalid_url"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        startTest "Should fail to get a repository with an invalid URL"
        if ! "$shucmd" get "invalid-url" > /dev/null 2>&1; then
            sucess
        else
            failure "shu get did not fail with an invalid URL."
        fi

        startTest "Should create empty .shu/packages"
        if [ -d "./.shu/packages" ] && [ "$(ls -A ./.shu/packages)" ]; then
            failure "shu get created a non-empty .shu/packages directory for an invalid URL."
        else
            sucess
        fi

    }; test_get_repo_with_invalid_url

    #test a repository like 'path/to/repo@tag'
    test_get_repo_with_tag(){
        cd "$mainDir"
        createFakeGitRepo "withTag_repo1"; local repo="$_r"
        createFakeGitRepo "withTag_repo2"; local repo2="$_r"
        createFakeGitRepo "withTag_repo3"; local repo3="$_r"

        #enter git repo and create a tag
        cd "$repo"
        echo "This is a test file with tag" > test.txt
        git add test.txt > /dev/null 2>&1
        git commit -m "Initial commit with tag" > /dev/null 2>&1
        git tag v1.0.0 > /dev/null 2>&1

        cd "$repo2"
        echo "This is a second test file with tag" > test.txt
        git add test.txt > /dev/null 2>&1
        git commit -m "Initial commit with tag" > /dev/null 2>&1
        git tag v1.0.0 > /dev/null 2>&1

        cd "$repo3"
        echo "This is a third test file with tag" > test.txt
        git add test.txt > /dev/null 2>&1
        git commit -m "Initial commit with tag" > /dev/null 2>&1
        git tag v1.0.0 > /dev/null 2>&1

        cd "$mainDir"

        local tmpdir="$tempDir$(mktemp -u)_get_with_tag"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        #call shu get with tag
        "$shucmd" get "$repo@v1.0.0" > /dev/null
        "$shucmd" get "$repo2@v1.0.0" > /dev/null
        "$shucmd" get "$repo3@v1.0.0" > /dev/null

        local repoBasename=$(basename "$repo")
        local repoBasename2=$(basename "$repo2")
        local repoBasename3=$(basename "$repo3")

        startTest "Should create the first repository directory with tag"
        if [ -d "./.shu/packages/$repoBasename" ]; then
            sucess
        else
            failure "'shu get' failed to clone the repository with tag."
        fi

        startTest "Should create a second repository directory with tag"
        if [ -d "./.shu/packages/$repoBasename2" ]; then
            sucess
        else
            failure "'shu get' failed to clone the second repository with tag."
        fi

        startTest "Should create a third repository directory with tag"
        if [ -d "./.shu/packages/$repoBasename3" ]; then
            sucess
        else
            failure "'shu get' failed to clone the third repository with tag."
        fi

    }; test_get_repo_with_tag

    #clone a git repository and get only the specified subfolder (e.g. 'path/to/repo#subfolder')
    test_get_repo_with_subfolder(){ 
        cd "$mainDir"
        createFakeGitRepo "withSubFolder_repo1"; local repo="$_r"
        createFakeGitRepo "withSubFolder_repo2"; local repo2="$_r"
        createFakeGitRepo "withSubFolder_repo3"; local repo3="$_r"
        
        #enter git repo and create a subfolder
        _prepareRepo(){ local repoPath="$1"; local subFolderName=${2:-"subfolder"};
            cd "$repoPath"
            mkdir -p "$subFolderName"
            echo "This is a test file in $subFolderName" > "./$subFolderName/test2.txt"
            git add "./$subFolderName/test2.txt" > /dev/null 2>&1
            git commit -m "Initial commit with $subFolderName" > /dev/null 2>&1
        }
        _prepareRepo "$repo"
        _prepareRepo "$repo2" "subfolder2"
        _prepareRepo "$repo3"

        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_get_with_subfolder"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        #call shu get with subfolder
        startTest "Should clone the repository and get the subfolder"
        "$shucmd" get "$repo#subfolder" > /dev/null 2>/tmp/shu-cli-test-error.log
        if [ $? -ne 0 ]; then
            failure "'shu get' failed to clone the repository with subfolder: \n$(cat /tmp/shu-cli-test-error.log)"
        else
            sucess
        fi

        startTest "Should clone the second repository and get the subfolder"
        "$shucmd" get "$repo2#subfolder2" > /dev/null 2>/tmp/shu-cli-test-error.log
        if [ $? -ne 0 ]; then
            failure "'shu get' failed to clone the second repository with subfolder: \n$(cat /tmp/shu-cli-test-error.log)"
        else
            sucess
        fi
        rm /tmp/shu-cli-test-error.log


        #should raise an error because the subfolder already exists in the .shu/packages directory
        startTest "Should raise an error if the subfolder already exists"

        "$shucmd" get "$repo3#subfolder" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            sucess
        else
            failure "'shu get' did not raise an error for an existing subfolder."
        fi

    }; test_get_repo_with_subfolder

    #clone a git repository, checkout to a specific tag and get only the specified subfolder (e.g. 'path/to/repo@tag#subfolder')
    test_get_repo_with_tag_and_subfolder() { 
        cd "$mainDir"
        createFakeGitRepo "withTagAndSubfolder_repo1"; local repo="$_r"
        createFakeGitRepo "withTagAndSubfolder_repo2"; local repo2="$_r"
        createFakeGitRepo "withTagAndSubfolder_repo2"; local repo3="$_r"

        _prepareRepo(){ local repoPath="$1"; local subFolderName=${2:-"subfolder"};
            #enter git repo and create a subfolder
            cd "$repoPath"
            echo "This is a test file in subfolder with tag" > "test.txt"
            git add "test.txt" > /dev/null 2>&1
            git commit -m "Initial commit with subfolder and tag" > /dev/null 2>&1
            
            mkdir -p "$subFolderName"
            echo "This is a test file in subfolder with tag" > "$subFolderName/test.txt"
            git add "$subFolderName/test.txt" > /dev/null 2>&1
            git commit -m "Commit before create a tag" > /dev/null 2>&1
            git tag v1.0.0 > /dev/null 2>&1
        }
        _prepareRepo "$repo"
        _prepareRepo "$repo2" "subfolder2"
        _prepareRepo "$repo3"

        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_get_with_tag_and_subfolder"
        mkdir -p "$tmpdir"

        cd "$tmpdir"
        #init project
        "$shucmd" init "test-project" > /dev/null



        _addAndCheckDep(){ local depRepo="$1"; local testMessage="$2"; local subFolderName=${3:-"subfolder"};
            #call shu get with tag and subfolder
            startTest "$testMessage"
            "$shucmd" get "$depRepo@v1.0.0#$subFolderName" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the repository with tag and $subFolderName: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else
                if [ -d "./.shu/packages/$subFolderName" ] && [ -f "./.shu/packages/$subFolderName/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the subfolder with tag."
                fi
            fi
        }

        _addAndCheckDep "$repo" "Should clone the repository, checkout to the tag and get the subfolder"
        _addAndCheckDep "$repo2" "Should clone the second repository, checkout to the tag and get the subfolder" "subfolder2"

        startTest "Should raise an error if the subfolder already exists"
        "$shucmd" get "$repo3@v1.0.0#subfolder" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            sucess
        else
            failure "'shu get' did not raise an error for an existing subfolder with tag."
        fi

    }; test_get_repo_with_tag_and_subfolder

    #force package name (call shu get with 'as <otherName>' option) {
        #similar to test_shu_get, but the 'as <otherName>' options is passed to shu get after the repository URL
        #the folder name inside ./.shu/packages should be the <otherName> instead of the repository name

        printSession "    Testing shu get with forced packages names"
        
        test_shu_get_and_force_packageName(){

            cd "$mainDir"
            createFakeGitRepo "forcePackageName_repo1"; local repo="$_r"
            createFakeGitRepo "forcePackageName_repo2"; local repo2="$_r"

            local tmpdir="$tempDir$(mktemp -u)_get_force_packageName"
            mkdir -p "$tmpdir"
            cd "$tmpdir"
            #init project
            "$shucmd" init "test-project" > /dev/null
            
            #call shu get with force package name
            "$shucmd" get "$repo" as "customName1" > /dev/null
            "$shucmd" get "$repo2" as "customName2" > /dev/null

            local repoBasename=$(basename "$repo")
            local repoBasename2=$(basename "$repo2")

            startTest "    Should create the first repository directory with custom name"
            if [ -d "./.shu/packages/customName1" ]; then
                sucess
            else
                failure "'shu get' failed to clone the repository with custom name."
            fi

            startTest "    Should create a second repository directory with custom name"
            if [ -d "./.shu/packages/customName2" ]; then
                sucess
            else
                failure "'shu get' failed to clone the second repository with custom name."
            fi

            startTest "    Should add the first repository to the shu.yaml file with custom name"
            #check if the repository was added to the shu.yaml file
            if yq ".deps" "./shu.yaml" | grep -q "customName1"; then
                sucess
            else
                failure "shu get did not add the first repository with custom name to the shu.yaml file."
            fi

            startTest "    Should add the second repository to the shu.yaml file with custom name"
            if yq ".deps" "./shu.yaml" | grep -q "customName2"; then
                sucess
            else
                failure "shu get did not add the second repository with custom name to the shu.yaml file."
            fi

            cd "$mainDir"
        }; test_shu_get_and_force_packageName

        test_get_repo_with_invalid_url_and_force_packageName(){
            cd "$mainDir"
            local tmpdir="$tempDir$(mktemp -u)_get_invalid_url_force_packageName"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            startTest "    Should fail to get a repository with an invalid URL and force package name"
            if ! "$shucmd" get "invalid-url" as "customName" > /dev/null 2>&1; then
                sucess
            else
                failure "shu get did not fail with an invalid URL and force package name."
            fi

            startTest "    Should create empty .shu/packages"
            if [ -d "./.shu/packages" ] && [ "$(ls -A ./.shu/packages)" ]; then
                failure "shu get created a non-empty .shu/packages directory for an invalid URL and force package name."
            else
                sucess
            fi
            cd "$mainDir"
        }; test_get_repo_with_invalid_url_and_force_packageName

        test_get_repo_with_tag_and_force_packageName(){
            cd "$mainDir"
            createFakeGitRepo "forcePackageNameWithTag_repo1"; local repo="$_r"
            createFakeGitRepo "forcePackageNameWithTag_repo2"; local repo2="$_r"

            #enter git repo and create a tag
            cd "$repo"
            echo "  This is a test file with tag and custom name" > test.txt
            git add test.txt > /dev/null 2>&1
            git commit -m "Initial commit with tag and custom name" > /dev/null 2>&1
            git tag v1.0.0 > /dev/null 2>&1

            cd "$repo2"
            echo "  This is a second test file with tag and custom name" > test.txt
            git add test.txt > /dev/null 2>&1
            git commit -m "Initial commit with tag and custom name" > /dev/null 2>&1
            git tag v1.0.0 > /dev/null 2>&1

            cd "$mainDir"
            local tmpdir="$tempDir$(mktemp -u)_get_with_tag_and_force_packageName"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            #call shu get with tag and force package name
            startTest "    Should clone the repository, checkout to the tag and get the subfolder with custom name"
            "$shucmd" get "$repo@v1.0.0" as "customName1" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the repository with tag and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else

                #check if the subfolder was cloned and contains the file test.txt
                if [ -d "./.shu/packages/customName1" ] && [ -f "./.shu/packages/customName1/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the repository with tag and custom name."
                fi
            fi
            rm /tmp/shu-cli-test-error.log

            startTest "    Should clone the second repository, checkout to the tag and get the subfolder with custom name"
            "$shucmd" get "$repo2@v1.0.0" as "customName2" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the second repository with tag and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else

                #check if the subfolder was cloned and contains the file test.txt
                if [ -d "./.shu/packages/customName2" ] && [ -f "./.shu/packages/customName2/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the second repository with tag and custom name."
                fi
            fi
            rm /tmp/shu-cli-test-error.log

            #should raise an error because the subfolder already exists in the .shu/packages directory
            startTest "    Should raise an error if the subfolder already exists with custom name"
            "$shucmd" get "$repo@v1.0.0" as "customName1" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                sucess
            else
                failure "'shu get' did not raise an error for an existing subfolder with custom name."
            fi

            cd "$mainDir"
            

        }; test_get_repo_with_tag_and_force_packageName

        test_get_repo_with_subfolder_and_force_packageName(){
            cd "$mainDir"
            createFakeGitRepo "forcePackageNameWithSubfolder_repo1"; local repo="$_r"
            createFakeGitRepo "forcePackageNameWithSubfolder_repo2"; local repo2="$_r"

            _prepareRepo(){ local repoPath="$1"; local subFolderName=${2:-"subfolder"};
                #enter git repo and create a subfolder
                cd "$repoPath"
                mkdir -p "$subFolderName"
                echo "This is a test file in $subFolderName with custom name" > "./$subFolderName/test.txt"
                git add "./$subFolderName/test.txt" > /dev/null 2>&1
                git commit -m "Initial commit with $subFolderName and custom name" > /dev/null 2>&1
            }
            _prepareRepo "$repo"
            _prepareRepo "$repo2" "subfolder2"

            cd "$mainDir"
            local tmpdir="$tempDir$(mktemp -u)_get_with_subfolder_and_force_packageName"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            #call shu get with subfolder and force package name
            startTest "    Should clone the repository and get the subfolder with custom name"
            "$shucmd" get "$repo#subfolder" as "customName1" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the repository with subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else
                #check if the subfolder was cloned and contains the file test.txt
                if [ -d "./.shu/packages/customName1" ] && [ -f "./.shu/packages/customName1/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the subfolder with custom name."
                fi
            fi

            startTest "    Should clone the second repository and get the subfolder with custom name"
            "$shucmd" get "$repo2#subfolder2" as "customName2" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the second repository with subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else

                #check if the subfolder was cloned and contains the file test.txt
                if [ -d "./.shu/packages/customName2" ] && [ -f "./.shu/packages/customName2/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the second repository with subfolder and custom name."
                fi
            fi
            rm /tmp/shu-cli-test-error.log
            
            #should raise an error because the subfolder already exists in the .shu/packages directory
            startTest "    Should raise an error if the subfolder already exists with custom name"
            "$shucmd" get "$repo#subfolder" as "customName1" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                sucess
            else
                failure "'shu get' did not raise an error for an existing subfolder with custom name."
            fi

            cd "$mainDir"
        }; test_get_repo_with_subfolder_and_force_packageName

        test_get_repo_with_tag_and_subfolder_and_force_packageName(){
            cd "$mainDir"
            createFakeGitRepo "forcePackageNameWithTagAndSubfolder_repo1"; local repo="$_r"
            createFakeGitRepo "forcePackageNameWithTagAndSubfolder_repo2"; local repo2="$_r"

            _prepareRepo(){ local repoPath="$1";
                #enter git repo and create a subfolder
                cd "$repoPath"
                mkdir -p "subfolder"
                echo "This is a test file in subfolder with tag and custom name" > "test.txt"
                git add "test.txt" > /dev/null 2>&1
                git commit -m "Initial commit with subfolder and tag and custom name" > /dev/null 2>&1
                mkdir -p "subfolder"
                echo "This is a test file in subfolder with tag and custom name" > "subfolder/test.txt"
                git add "subfolder/test.txt" > /dev/null 2>&1
                git commit -m "Commit before create a tag with subfolder and custom name" > /dev/null 2>&1
                git tag v1.0.0 > /dev/null 2>&1
            }
            _prepareRepo "$repo"
            _prepareRepo "$repo2"

            cd "$mainDir"
            local tmpdir="$tempDir$(mktemp -u)_get_with_tag_and_subfolder_and_force_packageName"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            #call shu get with tag, subfolder and force package name
            startTest "    Should clone the repository, checkout to the tag and get the subfolder with custom name"
            "$shucmd" get "$repo@v1.0.0#subfolder" as "customName1" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the repository with tag, subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else

                #check if the subfolder was cloned and contains the file test.txt
                if [ -d "./.shu/packages/customName1" ] && [ -f "./.shu/packages/customName1/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the repository with tag, subfolder and custom name."
                fi
            fi
            rm /tmp/shu-cli-test-error.log

            startTest "    Should clone the second repository, checkout to the tag and get the subfolder with custom name"
            "$shucmd" get "$repo2@v1.0.0#subfolder" as "customName2" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                failure "'shu get' failed to clone the second repository with tag, subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                rm /tmp/shu-cli-test-error.log
            else

                #check if the subfolder was cloned and contains the file test.txt
                if [ -d "./.shu/packages/customName2" ] && [ -f "./.shu/packages/customName2/test.txt" ]; then
                    sucess
                else
                    failure "shu get did not clone the second repository with tag, subfolder and custom name."
                fi
            fi
            rm /tmp/shu-cli-test-error.log

            #should raise an error because the subfolder already exists in the .shu/packages directory
            startTest "    Should raise an error if the subfolder already exists with custom name"
            "$shucmd" get "$repo@v1.0.0#subfolder" as "customName1" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                sucess
            else
                failure "'shu get' did not raise an error for an existing subfolder with custom name."
            fi
            cd "$mainDir"
        }; test_get_repo_with_tag_and_subfolder_and_force_packageName
    #}

#}

#shu clean{
    printSession "Testing shu clean"
    test_shu_clean(){
        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_clean"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        #create a file in the .shu/packages directory
        mkdir -p "./.shu/packages/test-package"
        echo "This is a test file" > "./.shu/packages/test-package/test.txt"

        startTest "Should remove the .shu/packages directory"
        "$shucmd" clean > /dev/null

        if [ ! -d "./.shu" ]; then
            sucess
        else
            failure "shu clean did not remove the .shu/packages directory."
        fi

        cd "$mainDir"
    }; test_shu_clean

#}

#shu restore{
    printSession "Testing shu restore"
    test_shu_restore(){
        cd "$mainDir"
        createFakeGitRepo; local repo="$_r"
        createFakeGitRepo; local repo2="$_r"
        createFakeGitRepo; local repo3="$_r"

        local tmpdir="$tempDir""$(mktemp -u)_restore"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        #call shu get
        "$shucmd" get "$repo" > /dev/null
        "$shucmd" get "$repo2" > /dev/null
        "$shucmd" get "$repo3" > /dev/null

        rm -rf "./.shu"
        startTest "Project directory should be clean before restoring test"
        if [ ! -d "./.shu" ]; then
            sucess
        else
            failure
            return 1
        fi

        "$shucmd" restore > /dev/null
        if [ $? -ne 0 ]; then
            failure "'shu restore' failed."
            return 1
        fi

        local repoBasename="$(basename "$repo")"
        local repoBasename2="$(basename "$repo2")"
        local repoBasename3="$(basename "$repo3")"

        startTest "Should restore the first repository directory"
        if [ -d "./.shu/packages/$repoBasename" ]; then
            sucess
        else
            failure "'shu get' failed to clone the repository."
        fi

        startTest "Should restore a second repository directory"
        if [ -d "./.shu/packages/$repoBasename2" ]; then
            sucess
        else
            failure "'shu get' failed to clone the second repository."
        fi

        startTest "Should restore a third repository directory"
        if [ -d "./.shu/packages/$repoBasename3" ]; then
            sucess
        else
            failure "'shu get' failed to clone the third repository."
        fi

        
        cd "$mainDir"
        
    }; test_shu_restore
#}
printResume
retCode=$?
if [ "$eraseTempFolderAfterTests" = "true" ]; then
    rm -rf "$tempDir/"
fi
exit $retCode
