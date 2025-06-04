# SHU - Previously shell script utils

Shu is a shell script framework that provides new features for shell scripting programming. These features are:
    Object orientation - You can write classes, inherits existing classes and instantiate objects.
    Anonimous functions - Shu adds support for anonimous functions in shell scripts. Anonimous functions are functions that are not named and can be passed as parameters to other functions.
    Defer keyword - Defer is a keyword that allows you to defer the execution of a command to the end of the current fuction. This is useful when you need to execute a command after the script ends, like closing a file or a connection.

    import - Import is a keywork that tells shu that an external module needs to be downloaded and make available to your scripts. Modules are git repositories with .sh files.

    Embedded libraries - Shu provides a set of libraries that can be used in your shell scripts.

    promise - This resource is similar to other languages and are provides by a internal library.

    extensible logs - Extensible logs are you to write your own log writer and integrate with a central log system. Logger are the name of the library that provides this features and it works with a driver system. You can write your own driver and integrate with the logger.

    Concurrent programming - Shu provides a file called 'program.sh'. This file starts a scheduler that allow you to run concurrent (not parallel) tasks.

# Downloading and installing shu cli (command line interface)

SHU cli are published among with the shu framework, and can be downloaded from the releases pages on GitHub. When a new version is released, some artifacts are created: the shu framework, with shu .sh files and all the SHU source code, the SHU cli binaries, with a installation script (install.sh), and the install.sh script uncompressed.

The install.sh file is available as a separate artifact, allowing you to install the shu cli without downloading the entire shu framework. To install the shu cli using the install.sh direct from the releases page, you can use the following command:

```sh
    source <(curl -sL https://raw.githubusercontent.com/rafael-tonello/shellscript_utils/refs/heads/main/versioninfo.sh)
    curl -sL "https://github.com/rafael-tonello/shellscript_utils/releases/download/$SHU_LAST_VERSION/install.sh" | bash
```
The script 'install.sh' will detect you do not have the 'shu' amont 'install.sh' file and will automatically download and install SHU binary to /usr/local/bin. 

A Warning: the 'install.sh' script every time will download (or detect the 'shu' among the 'install.sh') and will replace the 'shu' file in /usr/local/bin, so you can use it to update the shu cli, But if you run it in a folter with a 'shu' file, it will replace the file /usr/local/bin/shu with the file in the folder, thus can make a shu downgrade.

For simplicity and security, just use the command above to automatically install the shu cli from the repositores.

# some examples of shu codes

Before entering in the internals of SHU, lets see how it works and allow you to do with some examples.

## Creating a simple class
classes are files where all functions and properties are prefixed with context 'this'.

```sh
    #myclass.sh

    #!/bin/bash

    this->init() {
        this->name="John Doe"

        this->sayHello
    }

    this->sayHello() {
        echo "Hello, my name is $this->name"
    }
```
Running the code
```sh
    shu run --main myclass.sh
```

as 'myClass.sh' is the main file (as it was specified through the --main parameter), shu will automatically create a instance of the myClass class, and the init method (that is like a constructor) will be called.

## Using lambda/anonimous function
Anonymous functions are functions that are not named and can be passed as parameters to other functions.

```sh
    #!/bin/bash

    this->init() {
        this->name="John Doe"

        thi doSomething (){
            echo "I'm a lambda function"
        }
    }

    this->doSomething() { callback=$1
        (
            #atention to context lost. This are running in a subshell
            sleep 5
            callback
        ) &
    }



    #$ shu run --main=./myproject.sh

    ##output
    #I'm a lambda function
```

Lambda function will have access to the context of the function calling it. It means that a lambda/anonymous function have acces to the 'local' variables of its parent function.
```sh
    #!/bin/bash

    this->init() {
        local name="John Doe"

        this->doSomething (){
            echo "I'm a lambda function"
            echo "Hello, my name is $name"
        }
    }

    this->doSomething() { callback=$1
        (
            #atention to context lost. This are running in a subshell
            sleep 5
            callback
        ) &
    }

    ##output
    #I'm a lambda function
    #Hello, my name is John Doe
```

Note: SHU contains an internal system that allow concurrent programming. Do not worry about it by now (we will see it bellow). Just remember that lambda function will have acces to the parent function context while the parent function is running. 

Using concurrent programming, is normal that the anonymous functions are uses as callbacks, and executed after the parent function ends. In these cases, the context of the parent function will be lost and the lambda will no be able to acces this context (context is destroyed when a function ends).

## Using defer keyword
The defer keyword was inspired by golang, and allows you to defer the execution of a command to the end of the current function.

```sh
    #!/bin/bash

    this->init() {
        defer echo "exiting from init"
        this->name="John Doe"

        this->sayHello
    }

    this->sayHello() {
        echo "entering in sayHello"
        this->defer echo "Goodbye, my name is $this->name"
        defer echo "exiting from sayHello"
        echo "Hello, my name is $this->name"
    }


    ##output:
    #entering in sayHello
    #Hello, my name is John Doe
    #Goodbye, my name is John Doe
    #exiting from sayHello
    #exiting from init
```

## using scheduler
As mentioned before, SHU contains an internal system that allow concurrent programming. This system is the 'scheduler' that is availbale through the 'program.sh' file of SHU.

Shcueler is a object (a singleton, actually) that allow you to run cuncurrent tasks. Scheduler also allow you to run periodic and delayed tasks.

Scheduler cannot be instantiated by the user and is avaible through the global object 'scheduler'.

```shell script
    #!/bin/bash

    this->init() {
        this->name="John Doe"

        scheduler->run this->call_this_method
        scheduler->run (){
            echo "I'm a lambda function"
        }

        scheduler->runDelayed call_this_method2 2
        scheduler->runDelayed (){
            echo "I'm a lambda function"
        } 2

        #after 3 seconds from startup, stops the scheduler, causing the script to end
        scheduler->runDelayed (){
            scheduler->stop
        } 3
    }

    this->call_this_method() {
        echo "I'm a method"
    }

    this->call_this_method2() {
        echo "I'm another method"
    }

# shu run --main=./myproject.sh

## output:
# I'm a method
# I'm a lambda function
# I'm another method
# I'm a lambda function
# $
```

## Using promises
Promises allow you to be notified when one task is completed (or failed). Promise are provided by an internal SHU class and are very easy to use.

```shell
    this->init(){ 
        #call the method that will create the promise
        this->waitFile "/tmp/myfile"

        #when the promise is resolved, the scheduler will stop
        this->promise->then (){
            echo "file found"
            scheduler->stop
        }

        #create a delayed task that will create the file after 5 seconds
        scheduler->runDelayed (){
            touch /tmp/myfile
        } 5
    }

    this->waitFile(){ $file="$1"
        local intervalSeconds=1

        #create a new promise
        new Promise this->thePromise

        this->taskId = scheduler->periodicTask (){
            #check if the file exists
            if [ -f "$file" ]; then
                scheduler->erasePeriodic $this->taskId

                #resolve the promise
                this->thePromise->resolve
            fi
        } $intervalSeconds
    }
```

### returning promises (and objects)
As you can see, we  used a class property to store the promise. It works well when you have only one call to a funciton that returns a promise, of for simple classes, but for more complex classes, it became useless. As you can do in another languages, you could return objects from functions. To allow it, SHU have a convention that uses _r global variable as a return values of function (due to the fact that bash should return exit codes, ant not values). 

Returned values are in fact the names of the objects, so you cannot create object as local variables and return it.

So lets change the Promises example to return the promise object.

```shell
    this->init(){ 
        #call the method that will create the promise
        this->waitFile "/tmp/myfile"
        local theProm="$_r"

        #when the promise is resolved, the scheduler will stop
        eval "$theProm"'->then(){
            echo "file found"
            scheduler->stop
        }'

        #create a delayed task that will create the file after 5 seconds
        scheduler->runDelayed (){
            touch /tmp/myfile
        } 5
    }

    this->waitFile(){ $file="$1"
        local intervalSeconds=1

        #create a new promise
        new Promise myProm

        this->taskId = scheduler->periodicTask (){
            #check if the file exists
            if [ -f "$file" ]; then
                scheduler->erasePeriodic $this->taskId

                #resolve the promise
                myProm->resolve
            fi
        } $intervalSeconds

        _r=$myProm
    }
```

### using refs to objects

As you can see, we needed to use eval to call the object methods, due the fact that variables store objects names. Is works well, but are a bit ugle for more complete programs. 
To lead with this scenarios, SHU provides a way to create a intermediate object that references the original object.


So, again, lets change the Promises example to use refs to objects.
```shell
    this->init(){ 
        #call the method that will create the promise
        this->waitFile "/tmp/myfile"
        newRef "$_r" thePromRef

        #when the promise is resolved, the scheduler will stop
        thePromRef->then(){
            echo "file found"
            scheduler->stop
        }

        #create a delayed task that will create the file after 5 seconds
        scheduler->runDelayed (){
            touch /tmp/myfile
        } 5
    }

    this->waitFile(){ $file="$1"
        local intervalSeconds=1

        #create a new promise
        new Promise myProm

        this->taskId = scheduler->periodicTask (){
            #check if the file exists
            if [ -f "$file" ]; then
                scheduler->erasePeriodic $this->taskId

                #resolve the promise
                myProm->resolve
            fi
        } $intervalSeconds

        _r=$myProm
    }
```

# Imporing modules


## "shu import" command
The 'shu import' command will download the module from the git repository and will place it in the ./shu/imports folder. The module will be downloaded only if it is not already downloaded. If the repository is already downloaded, the 'shu import' command will update the module to the latest version. 
```sh
    shu import "http://github.com/repo/module"
```

You can specify the commit, tag or branch of the repository to be downloaded by adding "@<checkoutto>" to the repository URL. If you do not specify the commit/tag/branch, the 'shu import' command will download the default branch of the repository and will checkout the latest commit.
 
```sh
    shu import "http://github.com/repo/module@v1.2.3"
```

If you want to import a module only if is not already downloaded, you can use the --no-update flag. In this case, the 'shu import' command will not update the module to the latest version if it is already downloaded.

Another information is that SHU mantains  a list of modules in the file shu_setup.sh. Allowing the easy restore of the modules. You can add, to your .gitignore file, the folder ./.shu.

You can clean the imports folder by using the 'shu import --clean' command. This command will remove all modules from the ./shu/imports folder.

To restore modules, you can use the 'shu import --restore' command or just compile or run your project. 

A curiosity: Even the SHU framework .sh files are downloaded by the 'shu import' command. In this case, you do not need to use an "import" or call the "shu import" command to download the SHU framework. The SHU framework is downloaded automatically when you run the 'shu' command for the first time in yuor project. 


## "import" keywork
SHU, when is compiling/parsing files, will look for the 'import' keyword and will checkoung the module to the folder ./shu/imports. Internally,   the command 'shu import' will be called. Note that in this case, "shu import" will be called with the arg '--no-update" 

## Git

## SHU Registry

shu registry search


# SHU Intenals

## New, what happens when you call it
The function new (and new_f) receives a class name (or a file path, in case of new_f), a name for the new object and a list of parameters. The new function (actually the new_f, thus new just identify the file of a class and redirects the execution to new_f) replace all ocurrences of "this" by "\<objectName\>" (the object name folowed by an underscore) and all ocurrences of '->' by '_'. This will create a entire set of functions and variables that are prefixed by the name of the object. This set of functions and variables with the same prefixed name are a SHU object.
After the creation of the new content, a new temporary file is created and loaded via 'source' command, and the 'init' method (\<objectName>_init) is called with the parameters passed to the new/new_f function.

## How anonymous functions works
Anonimous function are transpiled by SHU cli to a conventional bash function and its name is placed in the place of the lambda function. 

Anonimous functions are placed at the begining of its parent function, allowing it to have access to the parent function context.

this:
```shell

    this->parentFunction(){
        this->callAnonymous (){
            echo "I'm a lambda function"
            
            #lamda function like this will be called like is done to a regular function
            (){ 
                echo "Hello, my name is $this->name"
            }
        }

        this->callAnonymous (){
            echo "I'm another lambda"
        }

        echo "Done"
    }

    this->callAnonymous(){ callback=$1
        (
            sleep 5
            callback
        ) &
    }

``` 
Is turned in this:
```shell
    this->parentFunction(){
        __anonimous_function_1_1234(){
            __anonimous_function_2_4455(){
                echo "Hello, my name is $this->name"
            }
            echo "I'm a lambda function"
            
            #lamda function like this will be called like is done to a regular function
            __anonimous_function_2_4455
        }

        __anonimous_function_3_8282(){
            echo "I'm another lambda"
        }

        this->callAnonymous __anonimous_function_1_1234

        this->callAnonymous __anonimous_function_3_8282

        echo "Done"
    }

    this->callAnonymous(){ callback=$1
        (
            sleep 5
            callback
        ) &
    }
```



if you do not create a shu project with 'shu create', you will need to specify the mail file when compile or run the project. During the compilation process, the 'shu' will create the '.shu' files with latest shu scripts and will working as a conventional project. The only difference is that shu will not known what is your main file  and you will need to specify it. 
If you want to specify the mains file and turn your project into a shu project, you just need to create a file called 'main.info' inside the .shu folder containing the path of the main file (relative to your project root folder):

```sh
    echo "myproject.sh" > .shu/main.info

```

of course you can just call "shu new myproject --root=./". In this case, shu will detect that 'myproject.sh' already exists and will not create a new one. Shu will, however, create the .shu folder and the main.info file for you.



file created by the shu during the compilation process. This files initializes shu and initializes the main class
```shell scripot
    #file ./myproject.sh

    #shu initialization{
        source "./.shu/shu/src/program.sh"
        program_init "./.shu/shu/src" true false false
        scheduler_run(){
            new_f "$0" __app "$@"
            shu_exit_code=$?
            scheduler_stopWorkLoop
        }

        scheduler_workLoop
        exit $shu_exit_code
    #}

    this->init() {
        this->name="John Doe"

        this->sayHello
    }

    #remain myproject.sh content


```


* Shu removes all comments form files


```shell
    #!/bin/bash
    #install.sh content

    #check for sudo 
    #if [ "$EUID" -ne 0 ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run as root"
        exit
    fi

    scriptDir=$(dirname $(readlink -f $0))
    copyFrom="$scriptDir/shu"

    if [ ! -f "$copyFrom" ]; then
        #download shu
        version="latest"

        if [ "$version" == "latest" ]; then
            source <(curl -sL https://raw.githubusercontent.com/rafael-tonello/shellscript_utils/refs/heads/main/versioninfo.sh)
            version=$SHU_LAST_VERSION
        fi

        platform=$(uname -m)

        echo "Downloading shu version $version"
        
        rm -rf /tmp/shu.tar.gz > /dev/null 2>&1
        curl -sL "https://github.com/rafael-tonello/shellscript_utils/releases/download/$version/shu_$version""_$platform"".tar.gz" -o "/tmp/shu.tar.gz"
        if [ $? -ne 0 ]; then
            echo "Error downloading SHU"
            exit 1
        fi

        tar -xzf /tmp/shu.tar.gz -C /tmp
        if [ $? -ne 0 ]; then
            echo "Error extracting SHU"
            exit 1
        fi
        copyFrom="/tmp/shu"
    fi

    if [ ! -f "$copyFrom" ]; then
        echo "Error getting SHU binary"
        exit 1
    fi

    if [ -f "/usr/local/bin/shu" ]; then
        echo "Removing old shu"
        rm /usr/local/bin/shu
    fi

    echo "Installing shu"
    cp "$copyFrom" /usr/local/bin/shu

    if [ $? -ne 0 ]; then
        echo "Error installing SHU"
        exit 1
    fi

    echo "SHU installed!"
    echo "use shu --help to see the available commands"
```

``` sh
    #!/bin/bash
    #applyversion.sh content

arduino vs espedicf
    #change all file content of versioninfo.sh
    sed -i "s/SHU_VERSION=.*/SHU_VERSION=\"$1\"/" ./versioninfo.sh

    #change the line "version="..." to "version="$1" in the install.sh file
    sed -i "s/version=\".*\"/version=\"$1\"/" ./install.sh
```

Fazer um papper




shu import "http:/.../" 
    import a module (download it to ./shu/imports and add the line 'import http://...' to file shu_setup.sh)

shu import --clean 
    remove all modules from ./shu/imports

shu import --restore 
    download all modules listed in shu_setup.sh

shu run --main=myproject.sh 
    run the project (compiles to a temporary folder and run it the file <tmpfolder>/myproject.sh. The
    workingdirectory is the project root folder, not the temporary folder)

shu compile --main=myproject.sh 
    compile the project to a single file

shu compile --main=myproject.sh --output=myproject.sh 
    compile the project to a single file called myproject.sh

shu compile --main=myproject.sh --output=myproject --no-compress 
    compile the project to a folder called myproject

shu create myproject 
    create a template project in the folder "myproject":
        ./myproject/.shu folder is created
        ./myproject/shu_setup.sh is created
        ./myproject/myproject.sh is created with a "helo world" example

shu clean 
    remove the ./shu folder