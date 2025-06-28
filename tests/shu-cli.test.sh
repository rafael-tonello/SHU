 #!/bin/bash
#setup {
    #cp ./shu-cli.sh /tmp/
    #shucmd="/tmp/shu-cli.sh"
    thisScriptLocation=$(dirname "$(readlink -f "$0")")
    shucmd="$thisScriptLocation/../src/shu-cli.sh"
    chmod +x "$shucmd"

    source "$thisScriptLocation/../src/libs/common/tests.sh"
    tempDir="/tmp/shu-cli-test"
    eraseTempFolderAfterTests=true
    #tempDir="./tmp"
    #eraseTempFolderAfterTests=false

    mainDir=$(pwd)
    rm -rf "$tempDir"
#}

#Note: All Calls to 'shu' are with stdout and stderr supressed.

main(){
    #Test_Init
    #MainFileTests
    #DepTests
    #CleanTests
    #TestRestore
    #TouchTests
    #HookTests
    ShuPpropsTests
}

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

Test_Init(){
    Tests.BeginGroup "Testing shu init"
    test_shu_init_withNoProjectName(){
        cd "$mainDir"
        Tests.BeginTest "Should use folder name if no project name is given"
        local tmpdir="$tempDir$(mktemp -u)_init_with_no_name"
        mkdir -p "$tmpdir"
        cd "$tmpdir"
        
        "$shucmd" init > /dev/null

        if [ -f "./shu.yaml" ]; then
            Tests.Success
        else
            Tests.Fail "shu init (with no name) failed. File shu.yaml was not created."
        fi
        cd "$mainDir"
    };
    
    test_shu_int(){
        cd "$mainDir"
        Tests.BeginTest "Should create a shu.yaml file with the given project name"
        local tmpdir="$tempDir$(mktemp -u)_init_with_name"

        mkdir -p "$tmpdir"
        cd "$tmpdir"

        "$shucmd" init "test-project" > /dev/null

        if [ -f "./shu.yaml" ]; then
            Tests.Success
        else
            Tests.Fail "shu init (with name) did not create .shu.yaml file."
        fi

        #check if the file contains the project name (user yq to get .Should clone the repository, checkout to the tag and get the subfoldername property)
        Tests.BeginTest "Should write the project name to the shu.yaml file"
        if yq ".name" "./shu.yaml" | grep -q "test-project"; then
            Tests.Success
        else
            Tests.Fail "Test failed: .shu.yaml does not contain the correct project name."
        fi
        cd "$mainDir"
    }; 

    test_shu_init_withNoProjectName
    test_shu_int

    Tests.EndGroup
}

MainFileTests(){
    Tests.BeginGroup "Testing mainfiles commands"
    #shu mainfiles add (shu setmain) tests {
        Tests.BeginGroup "Testing shu setmain"
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
            "$shucmd" mainfiles add "main.sh" > /dev/null
            "$shucmd" mainfiles add "main2.sh" > /dev/null

            #check if the "main.sh" file was added to the 'main' list of the shu.yaml file
            Tests.BeginTest "Setmain should the scriptname to the shu.yaml file"
            if yq ".main" "./shu.yaml" | grep -q "main.sh"; then
                Tests.Success
            else
                Tests.Fail "shu setmain failed to set the main script."
            fi

            #check if the main2.sh file was not added to the 'main' list of the shu.yaml file
            #if yq eval ".\"$key\"[]" "$file" | grep -Fxq "$value"; then
            Tests.BeginTest "Setmain should add the second script to the main list"
            if yq eval ".\"main\"[]" "./shu.yaml" | grep "main2.sh" > /dev/null; then
                Tests.Success
            else
                Tests.Fail "shu setmain incorrectly added main2.sh to the main list."
            fi

            cd "$mainDir"
        }; test_shu_setmain
        Tests.EndGroup
    #}

    #shu mainfiles remove tests {
        Tests.BeginGroup "Testing shu mainfiles remove"
        test_shu_mainfile_remove(){
            cd "$mainDir"

            local tmpdir="$tempDir$(mktemp -u)_mainfile_remove"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            echo "#!/bin/sh" > "./main.sh"
            echo "echo 'This is the main script'" >> "./main.sh"
            echo "" >> "./main.sh"

            chmod +x "./main.sh"

            #set main
            "$shucmd" mainfiles add "main.sh" > /dev/null

            #remove main
            "$shucmd" mainfiles remove "main.sh" > /dev/null

            #check if the "main.sh" file was removed from the 'main' list of the shu.yaml file
            Tests.BeginTest "mainfiles remove should remove the scriptname from the shu.yaml file"
            if ! yq ".main" "./shu.yaml" | grep -q "main.sh"; then
                Tests.Success
            else
                Tests.Fail "shu mainfiles remove failed to remove the main script."
            fi

            cd "$mainDir"
        }; test_shu_mainfile_remove
        Tests.EndGroup

    #}

    #shu mainfiles list tests{
        Tests.BeginGroup "Testing shu mainfiles list"
        test_shu_mainfile_list(){
            cd "$mainDir"

            local tmpdir="$tempDir$(mktemp -u)_mainfile_list"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            echo "#!/bin/sh" > "./main.sh"
            echo "echo 'This is the main script'" >> "./main.sh"
            echo "" >> "./main.sh"

            chmod +x "./main.sh"

            #set main
            "$shucmd" mainfiles add "main.sh" > /dev/null

            #list mainfiles
            Tests.BeginTest "mainfiles list should list the main files"
            if "$shucmd" mainfiles list | grep -q "main.sh"; then
                Tests.Success
            else
                Tests.Fail "shu mainfiles list failed to list the main file."
            fi

            cd "$mainDir"
        }; test_shu_mainfile_list

        Tests.EndGroup
    #}

    Tests.EndGroup
}

DepTests(){
    Tests.BeginGroup "Testing shu pdeps subcommand"
    #shu pdeps get (shu get) tests{
    DepTestsMain(){
        DepTests_Get
        DepTests_Remove
        DepTests_List
    }

    DepTests_Get(){
        Tests.BeginGroup "Testing shu get"

        test_shu_get_main(){
            test_shu_get
            test_get_repo_with_invalid_url
            test_get_repo_with_tag
            test_get_repo_with_subfolder
            test_get_repo_with_tag_and_subfolder
            DepTests_Get_ForcePackageName
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

            Tests.BeginTest "Should create the first repository directory"
            if [ -d "./.shu/packages/$repoBasename" ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' failed to clone the repository."
            fi

            Tests.BeginTest "Should create a second repository directory"
            if [ -d "./.shu/packages/$repoBasename2" ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' failed to clone the second repository."
            fi

            Tests.BeginTest "Should create a third repository directory"
            if [ -d "./.shu/packages/$repoBasename3" ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' failed to clone the third repository."
            fi

            Tests.BeginTest "Should add the first repository to the shu.yaml file"
            #check if the repository was added to the shu.yaml file
            if yq ".packages" "./shu.yaml" | grep -q "$repoBasename"; then
                Tests.Success
            else
                Tests.Fail "shu get did not add the first repository to the shu.yaml file."
            fi

            Tests.BeginTest "Should add the second repository to the shu.yaml file"
            if yq ".packages" "./shu.yaml" | grep -q "$repoBasename2"; then
                Tests.Success
            else
                Tests.Fail "shu get did not add the second repository to the shu.yaml file."
            fi

            Tests.BeginTest "Should add the third repository to the shu.yaml file"
            if yq ".packages" "./shu.yaml" | grep -q "$repoBasename2"; then
                Tests.Success
            else
                Tests.Fail "shu get did not add the third repository to the shu.yaml file."
            fi
            
            cd "$mainDir"
        }; 

        test_get_repo_with_invalid_url(){
            cd "$mainDir"
            
            local tmpdir="$tempDir$(mktemp -u)_get_invalid_url"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            Tests.BeginTest "Should fail to get a repository with an invalid URL"
            if ! "$shucmd" get "invalid-url" > /dev/null 2>&1; then
                Tests.Success
            else
                Tests.Fail "shu get did not fail with an invalid URL."
            fi

            Tests.BeginTest "invalid-url should not be listed in folder .shu/packages"
            if ! yq ".packages" "./shu.yaml" | grep -q "invalid-url"; then
                Tests.Success
            else
                Tests.Fail "shu get added an invalid URL to the shu.yaml file."
            fi

        }; 

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

            Tests.BeginTest "Should create the first repository directory with tag"
            if [ -d "./.shu/packages/$repoBasename" ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' failed to clone the repository with tag."
            fi

            Tests.BeginTest "Should create a second repository directory with tag"
            if [ -d "./.shu/packages/$repoBasename2" ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' failed to clone the second repository with tag."
            fi

            Tests.BeginTest "Should create a third repository directory with tag"
            if [ -d "./.shu/packages/$repoBasename3" ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' failed to clone the third repository with tag."
            fi

        }; 

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
            Tests.BeginTest "Should clone the repository and get the subfolder"
            "$shucmd" get "$repo#subfolder" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                Tests.Fail "'shu get' failed to clone the repository with subfolder: \n$(cat /tmp/shu-cli-test-error.log)"
            else
                Tests.Success
            fi

            Tests.BeginTest "Should clone the second repository and get the subfolder"
            "$shucmd" get "$repo2#subfolder2" > /dev/null 2>/tmp/shu-cli-test-error.log
            if [ $? -ne 0 ]; then
                Tests.Fail "'shu get' failed to clone the second repository with subfolder: \n$(cat /tmp/shu-cli-test-error.log)"
            else
                Tests.Success
            fi
            rm /tmp/shu-cli-test-error.log


            #should raise an error because the subfolder already exists in the .shu/packages directory
            Tests.BeginTest "Should raise an error if the subfolder already exists"

            "$shucmd" get "$repo3#subfolder" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' did not raise an error for an existing subfolder."
            fi

        }; 

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
                Tests.BeginTest "$testMessage"
                "$shucmd" get "$depRepo@v1.0.0#$subFolderName" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the repository with tag and $subFolderName: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else
                    if [ -d "./.shu/packages/$subFolderName" ] && [ -f "./.shu/packages/$subFolderName/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the subfolder with tag."
                    fi
                fi
            }

            _addAndCheckDep "$repo" "Should clone the repository, checkout to the tag and get the subfolder"
            _addAndCheckDep "$repo2" "Should clone the second repository, checkout to the tag and get the subfolder" "subfolder2"

            Tests.BeginTest "Should raise an error if the subfolder already exists"
            "$shucmd" get "$repo3@v1.0.0#subfolder" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                Tests.Success
            else
                Tests.Fail "'shu get' did not raise an error for an existing subfolder with tag."
            fi

        }; 

        #force package name (call shu get with 'as <otherName>' option) {
        DepTests_Get_ForcePackageName(){
            #similar to test_shu_get, but the 'as <otherName>' options is passed to shu get after the repository URL
            #the folder name inside ./.shu/packages should be the <otherName> instead of the repository name

            Tests.BeginGroup "Testing shu get with forced packages names"
            
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

                Tests.BeginTest "Should create the first repository directory with custom name"
                if [ -d "./.shu/packages/customName1" ]; then
                    Tests.Success 
                else
                    Tests.Fail "'shu get' failed to clone the repository with custom name."
                fi

                Tests.BeginTest "Should create a second repository directory with custom name"
                if [ -d "./.shu/packages/customName2" ]; then
                    Tests.Success
                else
                    Tests.Fail "'shu get' failed to clone the second repository with custom name."
                fi

                Tests.BeginTest "Should add the first repository to the shu.yaml file with custom name"
                #check if the repository was added to the shu.yaml file
                if yq ".packages" "./shu.yaml" | grep -q "customName1"; then
                    Tests.Success
                else
                    Tests.Fail "shu get did not add the first repository with custom name to the shu.yaml file."
                fi

                Tests.BeginTest "Should add the second repository to the shu.yaml file with custom name"
                if yq ".packages" "./shu.yaml" | grep -q "customName2"; then
                    Tests.Success
                else
                    Tests.Fail "shu get did not add the second repository with custom name to the shu.yaml file."
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

                Tests.BeginTest "Should fail to get a repository with an invalid URL and force package name"
                if ! "$shucmd" get "invalid-url" as "customName" > /dev/null 2>&1; then
                    Tests.Success
                else
                    Tests.Fail "shu get did not fail with an invalid URL and force package name."
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
                Tests.BeginTest "Should clone the repository, checkout to the tag and get the subfolder with custom name"
                "$shucmd" get "$repo@v1.0.0" as "customName1" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the repository with tag and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else

                    #check if the subfolder was cloned and contains the file test.txt
                    if [ -d "./.shu/packages/customName1" ] && [ -f "./.shu/packages/customName1/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the repository with tag and custom name."
                    fi
                fi
                rm /tmp/shu-cli-test-error.log

                Tests.BeginTest "Should clone the second repository, checkout to the tag and get the subfolder with custom name"
                "$shucmd" get "$repo2@v1.0.0" as "customName2" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the second repository with tag and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else

                    #check if the subfolder was cloned and contains the file test.txt
                    if [ -d "./.shu/packages/customName2" ] && [ -f "./.shu/packages/customName2/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the second repository with tag and custom name."
                    fi
                fi
                rm /tmp/shu-cli-test-error.log

                #should raise an error because the subfolder already exists in the .shu/packages directory
                Tests.BeginTest "Should raise an error if the subfolder already exists with custom name"
                "$shucmd" get "$repo@v1.0.0" as "customName1" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    Tests.Success
                else
                    Tests.Fail "'shu get' did not raise an error for an existing subfolder with custom name."
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
                Tests.BeginTest "Should clone the repository and get the subfolder with custom name"
                "$shucmd" get "$repo#subfolder" as "customName1" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the repository with subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else
                    #check if the subfolder was cloned and contains the file test.txt
                    if [ -d "./.shu/packages/customName1" ] && [ -f "./.shu/packages/customName1/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the subfolder with custom name."
                    fi
                fi

                Tests.BeginTest "Should clone the second repository and get the subfolder with custom name"
                "$shucmd" get "$repo2#subfolder2" as "customName2" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the second repository with subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else

                    #check if the subfolder was cloned and contains the file test.txt
                    if [ -d "./.shu/packages/customName2" ] && [ -f "./.shu/packages/customName2/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the second repository with subfolder and custom name."
                    fi
                fi
                rm /tmp/shu-cli-test-error.log
                
                #should raise an error because the subfolder already exists in the .shu/packages directory
                Tests.BeginTest "Should raise an error if the subfolder already exists with custom name"
                "$shucmd" get "$repo#subfolder" as "customName1" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    Tests.Success
                else
                    Tests.Fail "'shu get' did not raise an error for an existing subfolder with custom name."
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
                Tests.BeginTest "Should clone the repository, checkout to the tag and get the subfolder with custom name"
                "$shucmd" get "$repo@v1.0.0#subfolder" as "customName1" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the repository with tag, subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else

                    #check if the subfolder was cloned and contains the file test.txt
                    if [ -d "./.shu/packages/customName1" ] && [ -f "./.shu/packages/customName1/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the repository with tag, subfolder and custom name."
                    fi
                fi
                rm /tmp/shu-cli-test-error.log

                Tests.BeginTest "Should clone the second repository, checkout to the tag and get the subfolder with custom name"
                "$shucmd" get "$repo2@v1.0.0#subfolder" as "customName2" > /dev/null 2>/tmp/shu-cli-test-error.log
                if [ $? -ne 0 ]; then
                    Tests.Fail "'shu get' failed to clone the second repository with tag, subfolder and custom name: \n$(cat /tmp/shu-cli-test-error.log)"
                    rm /tmp/shu-cli-test-error.log
                else

                    #check if the subfolder was cloned and contains the file test.txt
                    if [ -d "./.shu/packages/customName2" ] && [ -f "./.shu/packages/customName2/test.txt" ]; then
                        Tests.Success
                    else
                        Tests.Fail "shu get did not clone the second repository with tag, subfolder and custom name."
                    fi
                fi
                rm /tmp/shu-cli-test-error.log

                #should raise an error because the subfolder already exists in the .shu/packages directory
                Tests.BeginTest "Should raise an error if the subfolder already exists with custom name"
                "$shucmd" get "$repo@v1.0.0#subfolder" as "customName1" >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                    Tests.Success
                else
                    Tests.Fail "'shu get' did not raise an error for an existing subfolder with custom name."
                fi
                cd "$mainDir"
            }; test_get_repo_with_tag_and_subfolder_and_force_packageName
        }

        test_shu_get_main
        
        Tests.EndGroup
    }

    DepTests_Remove(){
        Tests.BeginGroup "Testing shu pdeps remove"
        test_shu_dep_remove(){
            cd "$mainDir"
            createFakeGitRepo "removeTest_repo1"; local repo="$_r"
            createFakeGitRepo "removeTest_repo2"; local repo2="$_r"
            createFakeGitRepo "removeTest_repo3"; local repo3="$_r"

            local tmpdir="$tempDir$(mktemp -u)_dep_remove"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            #call shu get
            "$shucmd" get "$repo" > /dev/null
            "$shucmd" get "$repo2" > /dev/null
            "$shucmd" get "$repo3" > /dev/null

            Tests.BeginTest "should remove the repository from .shu/packages"

            "$shucmd" pdeps remove "$(basename "$repo2")" > /dev/null 2>/tmp/shu-cli-test-error.log

            if [ ! -d "./.shu/packages/$(basename "$repo2")" ]; then
                Tests.Success
            else
                Tests.Fail "shu pdeps remove did not remove the first repository from the .shu/packages directory: \n$(cat /tmp/shu-cli-test-error.log)"
            fi

            Tests.BeginTest "Should remove the repository from the shu.yaml file"
            if yq ".packages" "./shu.yaml" | grep -q "$(basename "$repo2")"; then
                Tests.Fail "shu pdeps remove did not remove the first repository from the shu.yaml file."
            else
                Tests.Success
            fi

            Tests.BeginTest "Should not remove other repositories from .shu/packages"
            if [ -d "./.shu/packages/$(basename "$repo")" ] && [ -d "./.shu/packages/$(basename "$repo3")" ]; then
                Tests.Success
            else
                Tests.Fail "shu pdeps remove removed other repositories from the .shu/packages directory."
            fi

            Tests.BeginTest "Should not remove other repositories from the shu.yaml file"
            if yq ".packages" "./shu.yaml" | grep -q "$(basename "$repo")" && yq ".packages" "./shu.yaml" | grep -q "$(basename "$repo3")"; then
                Tests.Success
            else
                Tests.Fail "shu pdeps remove removed other repositories from the shu.yaml file."
            fi
        }; 
        test_shu_dep_remove
        Tests.EndGroup
    }

    DepTests_List(){
        Tests.BeginGroup "Testing shu pdeps list"
        test_shu_dep_list(){
            cd "$mainDir"
            createFakeGitRepo "listTest_repo1"; local repo="$_r"
            createFakeGitRepo "listTest_repo2"; local repo2="$_r"
            createFakeGitRepo "listTest_repo3"; local repo3="$_r"

            local tmpdir="$tempDir$(mktemp -u)_dep_list"
            mkdir -p "$tmpdir"
            cd "$tmpdir"

            #init project
            "$shucmd" init "test-project" > /dev/null

            #call shu get
            "$shucmd" get "$repo" > /dev/null
            "$shucmd" get "$repo2" > /dev/null
            "$shucmd" get "$repo3" > /dev/null

            Tests.BeginTest "Should list all dependencies in the shu.yaml file"
            if "$shucmd" pdeps list | grep -q "$(basename "$repo")" && \
               "$shucmd" pdeps list | grep -q "$(basename "$repo2")" && \
               "$shucmd" pdeps list | grep -q "$(basename "$repo3")"; then
                Tests.Success
            else
                Tests.Fail "shu pdeps list did not list all dependencies."
            fi

            cd "$mainDir"
        }; test_shu_dep_list
        Tests.EndGroup
    }
    DepTestsMain

    Tests.EndGroup
}

CleanTests(){
    Tests.BeginGroup "Testing shu clean"
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

        Tests.BeginTest "Should remove the .shu/packages directory"
        "$shucmd" clean > /dev/null

        if [ ! -d "./.shu" ]; then
            Tests.Success
        else
            Tests.Fail "shu clean did not remove the .shu/packages directory."
        fi

        cd "$mainDir"
    }; test_shu_clean
    Tests.EndGroup

}

TestRestore(){
    Tests.BeginGroup "Testing shu restore"
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
        
        "$shucmd" restore >/dev/null 2> /tmp/shu-cli-test-error.log; local retCode=$?
        #echo "$shucmd"
        #"$shucmd" restore; local retCode=$?
        if [ $retCode -ne 0 ]; then
            Tests.Fail "'shu restore' failed.: \n$(cat /tmp/shu-cli-test-error.log)"
            return 1
        fi

        local repoBasename="$(basename "$repo")"
        local repoBasename2="$(basename "$repo2")"
        local repoBasename3="$(basename "$repo3")"

        Tests.BeginTest "Should restore the first repository directory"
        if [ -d "./.shu/packages/$repoBasename" ]; then
            Tests.Success
        else
            Tests.Fail "'shu get' failed to clone the repository."
        fi

        Tests.BeginTest "Should restore a second repository directory"
        if [ -d "./.shu/packages/$repoBasename2" ]; then
            Tests.Success
        else
            Tests.Fail "'shu get' failed to clone the second repository."
        fi

        Tests.BeginTest "Should restore a third repository directory"
        if [ -d "./.shu/packages/$repoBasename3" ]; then
            Tests.Success
        else
            Tests.Fail "'shu get' failed to clone the third repository."
        fi

        
        cd "$mainDir"
        
    }; test_shu_restore
    Tests.EndGroup

}

#shu build tests(){

#}

#shu psysdeps tests(){

#}

#shu install and uninstall tests{

#}

ShuPpropsTests(){
    Tests.BeginGroup "Testing shu pprops"
    cd "$mainDir"
    local tmpdir="$tempDir$(mktemp -u)_set_and_get_pprops"
    mkdir -p "$tmpdir"
    cd "$tmpdir"
    #init project
    "$shucmd" init "test-project"

    test_shu_set_and_get_pprops(){
        # set prop
        Tests.BeginTest "Should set a simple property"
        "$shucmd" pprops set "testProp" "testValue" > /dev/null 2>/tmp/shu-cli-test-error.log; local retCode=$?
        if [ $retCode -ne 0 ]; then
            Tests.Fail "'shu pprops set' failed to set the property: \n$(cat /tmp/shu-cli-test-error.log)"
            return 1
        else
            Tests.Success
        fi

        # get prop
        Tests.BeginTest "Should get the simple property"
        local propValue="$("$shucmd" pprops get "testProp")"
        if [ "$propValue" == "testValue" ]; then
            Tests.Success
        else
            Tests.Fail "'shu pprops get' failed to get the property value. Expected 'testValue', got '$propValue'."
        fi
    }
    
    test_array_with_simple_items(){
        # add simple item to array
        Tests.BeginTest "Should add a simple item to an array"
        "$shucmd" pprops addArrayItem "testArray" "item1" > /dev/null 2>/tmp/shu-cli-test-error.log; local retCode=$?
        if [ $? -eq 0 ]; then
            Tests.Success
        else
            Tests.Fail "'shu pprops addArrayItem' failed to add the item to the array: $(cat /tmp/shu-cli-test-error.log)"
        fi

        "$shucmd" pprops addArrayItem "testArray" "item2" > /dev/null 2>&1; local retCode=$?
        "$shucmd" pprops addArrayItem "testArray" "item3" > /dev/null 2>&1; local retCode=$?
        "$shucmd" pprops addArrayItem "testArray" "another item" > /dev/null 2>&1; local retCode=$?
        "$shucmd" pprops addArrayItem "testArray" "and here we have another item" > /dev/null 2>&1; local retCode=$?
        # list array with sinple items
        Tests.BeginTest "Should list the array with simple items" #> /dev/null 2>/tmp/shu-cli-test-error.log; local retCode=$?
        local arrayItems="$("$shucmd" pprops listArray "testArray")"
        if echo "$arrayItems" | grep -q "item1" && \
           echo "$arrayItems" | grep -q "item2" && \
           echo "$arrayItems" | grep -q "item3" && \
           echo "$arrayItems" | grep -q "another item" && \
           echo "$arrayItems" | grep -q "and here we have another item"; then
            Tests.Success
        else
            Tests.Fail "'shu pprops listArray' did not list all items in the array: $(cat shu-cli-test-error.log)"
        fi
    }

    # add object to array
    # get object from array
    # list array of objects
    
    # set array with single item and add an object
    # set array with object an get single item
    # set array with object and get array

    #list a mixex array of single items and objects
    test_shu_set_and_get_pprops
    test_array_with_simple_items
}


TouchTests(){
    Tests.BeginGroup "Testing shu touch"
    test_shu_touch(){
        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_touch"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        #create a file in the .shu/packages directory
        Tests.BeginTest "Should create the file with shu touch command"
        if "$shucmd" touch "test.sh" > /dev/null; then
            if [ -f "./test.sh" ]; then
                Tests.Success
            else
                Tests.Fail "File test.txt was not created."
            fi

            Tests.BeginTest "Should add the file to the shu.yaml file"
            #check if the file was added to the shu.yaml file
            if ! yq ".files[]" "./shu.yaml" | grep -q "test.txt"; then
                Tests.Success
            else
                Tests.Fail "File test.txt was added to the shu.yaml file."
            fi
        else
            Tests.Fail "'shu touch' failed to create the file."
        fi
    }; test_shu_touch

    test_shu_touch_with_addmain(){
        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_touch_with_addmain"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        #create a file in the .shu/packages directory
        Tests.BeginTest "Should create the file with shu touch command and add it to main"
        "$shucmd" touch "test.sh" --addmain >/dev/null; local retCode=$?
        if [ "$retCode" == "0" ];  then
            if [ -f "./test.sh" ]; then
                Tests.Success
            else
                Tests.Fail "File test.txt was not created."
            fi

            Tests.BeginTest "Should add the file to the shu.yaml file and to main"
            #check if the file was added to the shu.yaml file
            if yq ".main[]" "./shu.yaml" | grep -q "test.sh"; then
                Tests.Success
            else
                Tests.Fail "File test.txt was not added to the shu.yaml file."
            fi
        else
            Tests.Fail "'shu touch' failed to create the file."
        fi

    }; test_shu_touch_with_addmain

    test_shu_touch_with_no_args(){
        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_touch_with_no_args"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        Tests.BeginTest "Should raise an error if no arguments are given"
        "$shucmd" touch > /dev/null 2>&1; local retCode=$?
        if [ "$retCode" -ne 0 ]; then
            Tests.Success
        else
            Tests.Fail "'shu touch' did not raise an error for no arguments."
        fi
    }; test_shu_touch_with_no_args
    Tests.EndGroup
        
}

HookTests(){
    Tests.BeginGroup "Testing shu hooks"
    
    test_shu_hook(){
        cd "$mainDir"
        local tmpdir="$tempDir$(mktemp -u)_hook"
        mkdir -p "$tmpdir"
        cd "$tmpdir"

        #init project
        "$shucmd" init "test-project" > /dev/null

        Tests.BeginTest "should create the shu.yaml file"
        "$shucmd" hooks add before "pdeps list" "echo 'This is a test hooks' > /dev/null" > /dev/null
        if [ $? -eq 0 ]; then
            #check if shu.yaml contains the hooks
            shucontent=$(cat "./shu.yaml")
            if echo "$shucontent" | grep -q "when: before"; then
                if echo "$shucontent" | grep -q "shu-command: pdeps list"; then
                    if echo "$shucontent" | grep -q "cmd: echo 'This is a test hooks'"; then
                        Tests.Success
                    else
                        Tests.Fail "shu.yaml does not contain the correct 'action' for the hooks."
                    fi
                else
                    Tests.Fail "shu.yaml does not contain the correct 'command' for the hooks."
                fi
            else
                Tests.Fail "shu.yaml does not contain the correct 'when' condition for the hooks."
            fi
        else
            Tests.Fail "'shu hooks add' failed to create the hooks."
        fi

        Tests.BeginTest "should call the hooks when the command is executed"
        "$shucmd" hooks add before "pdeps list" "echo 'test1' > $tmpdir/f1" > /dev/null
        "$shucmd" hooks add before "pdeps list" "echo 'test2' > $tmpdir/f2" > /dev/null
        "$shucmd" pdeps list > /dev/null 2>/tmp/shu-cli-test-error.log; local retCode=$?
        if [ $retCode -eq 0 ]; then
            if [ -f "$tmpdir/f1" ] && [ -f "$tmpdir/f2" ]; then
                if grep -q "test1" "$tmpdir/f1" && grep -q "test2" "$tmpdir/f2"; then
                    Tests.Success
                else
                    Tests.Fail "hooks did not execute the commands correctly."
                fi
            else
                Tests.Fail "hooks did not create the expected files."
            fi
        else
            Tests.Fail "'shu pdeps list' failed to execute the hooks: \n$(cat /tmp/shu-cli-test-error.log)"
        fi
    }

    test_shu_hook

}

main

if [ "$eraseTempFolderAfterTests" = "true" ]; then
    rm -rf "$tempDir/"
fi
exit $retCode
