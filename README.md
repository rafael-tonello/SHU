Shu: A Shell Script Framework and Package Manager
# What is Shu?
Shu is a shell script framework and package manager that makes it easy to write and share shell scripts. It provides a simple way to manage dependencies, install packages, and run scripts.

# What I can do with aaa
* You can use and write libraries in shellscript, use it in you projects and share it with others.
* You can import existing shellscript projects, files and other git repositories.
* You can build you project in a single .sh file, which can be used as a standalone script.
* You can write and use libraries (packages) to share and reuse code.

# Getting Started
Install Shu
To install Shu, simply clone this repository and add the shu script to your system's PATH.

or use the following command to install it directly from the repository:

```bash
curl -sSL https://raw.githubusercontent.com/rafael-tonello/SHU/main/src/tools/shu-install.sh | bash
```

Initialize a New Project
To start a new project, run:

```bash
shu init myproject
```
This will create a new directory called myproject with a basic shu.yaml file and a main.sh script.


## Basic Commands
Here are some basic commands to get you started:

shu init [name]: Initialize a new Shu project.
shu get [package]: Retrieve a package and add it to your project's dependencies.
shu run [file]: Run a script or all scripts in your project's main section.
shu install [package]: Install a package system-wide.
How it Works
Shu uses a simple YAML file called shu.yaml to manage your project's dependencies and scripts. When you run a command, Shu reads the shu.yaml file and performs the necessary actions.

# Examples
Before diving int the details, let's look at some examples of how to use aaa.

## example 1 - Initing a basic project
```sh
shu init 'my project'
# this will create somes files and folders in the current directory:
# - my_project/
#   +->.shu/
#   |  +->packages/
#   |       +->shu-misc/
#   |           +->misc.sh (this is a basic library of Shu, and allow the easy import 
#   |                       of other libraries)
#   +->shu.yaml (This is the shu project file. It holds the packages of the 
#   |            ct, the main scripts and other metadata.)
#   +->main.sh (This is a basic script. You can start writting your code here.)

#main file content:
# !/usr/bin/env shu
# source ./shu/packages/shu-misc/misc.sh
# echo "Hello, world!"

./main.sh

#this will print to the console:
#$ Hello, world!
```

## example 2 - Importing a library
Initing the project and importing a library
```sh
shu init 'my project'

#import log library from shu repository
shu get "https://github.com/rafael-tonello/shu.git#src/libs/log as ShuLogger"
```

main file content
```sh
# !/usr/bin/env shu

#this is the basic library of SHU, and allow some useful functions. The importation occurs in the correct path, no matter where the script is executed.
source "$(dirname "${BASH_SOURCE[0]}")/.shu/packages/shu-misc/shu-misc.sh"

#import is a function from shu-misc, and allow you to easy sorce packages files (without need to source using the whole package path)
Import ShuLogger

#by default, _r is the used to return results from functions, avoiding spawning subshells.
log.New; log="$_r"

log.Info "main" "Hello, world!"

#this will print to the console something like:
#$ [ 20205-06-05 12:00:00.000][INFO][main] Hello, world!

```

This will create a new project called myscript, add the logger package as a dependency, write a simple script that uses the logger package, and run the script.

#Contributing
Contributions are welcome! If you'd like to contribute to Shu, please fork this repository and submit a pull request.

# How it works
## getting packages
Shu uses a simple YAML file called shu.yaml to manage your project's dependencies and scripts and .shu folder to store downloaded packages.
Packages can have its own shu.yaml, that will be read by shu and will have its own dependencies and scripts dowloaded (to its own .shu folder).

.shu folder can be deleted, and you can easyly restore it by running the command 'shu restore' or 'shu get' (with no args, shu get redirects to shu restore).
# License
Shu is licensed under the MIT License.

# Programming using Framework
Shu in addition to being a package manager CLI for shellscripting, it is also a framework for shell scripting. The SHU code contains some libraries that can be used to write shell scripts in a more structured way, allowing you to use object orientation, interfaces, and other programming concepts. And it have some important conventions that should be noticed, that is described below.

## Important concepts and conventions
To lead with the limitations of shell scripts, Shu uses some conventions and concepts that are important to understand when working with it.

Understanding these concepts is importante to effectively use Shu and to a further dive into its features.

* _r: Default return variable. To avoid spawning subshells and to allow returing values from functions, Shu uses the variable _r to return results.
* _error: The variable _error is used to return error messages from functions. You can use ':' to add context to error. A function should return an error or print it, but should avoid both. Also functions should return normal shellscript return codes.
* object orientation:
    * In the memory, objects are groups of variables that starts with a common prefix.
    * Classes and methods uses objects references (that are a prefix used by a group of variables).
    * classes are functions that receive an 'object' as the first parameter.
    * classes methods should be named <className>.<methodName>.
    * misc.sh contains functions to operate objects
        * o.New: creates a new object, returning it (the reference) in the _r variable.
        * o.Get: gets a property from an object, returning it in the _r variable.
        * o.Set: sets a property in an object. Multiple arguments will be set as an array.
        *o.Has: checks if an object has a property, returning true or false in the _r variable.
        * o.Delete: deletes a property from an object.
        * o.Destroy: destroys an object, deleting all its properties. If second argument is 'true', it will also delete all child obejects.
        * o.Implements: checks if an object (or class) implements a interface (another class).
        * o.Call: calls a method of an object. Shu will look for the className and call the function <className>.<methodName> with the object reference as the first parameter and the rest of arguments passed to the o.Call as remain arguments.
    * Shu uses 'duck typing'
    * To create objects, classes tipically implements a method called New (<className>.New). But you can use other functions. The functions that creates objects should return the object reference in the _r variable.

When you use 'shu init' or 'shu touch' command, the created file will have a important import line at the top, that sources the misc.sh file, allowing you to use the object manipulation functions.

```bash
#Interface IGreeter
    IGreeter.Greet(){ :; }


#MyClass definition
    MyClass.New(){
        if [ $# -ne 2 ]; then
            _error="MyClass.New: expected 2 arguments, got $#"
            return 1
        fi

        o.New MyClass; local ref="$_r"
        o.Set $ref name "$1"
        o.Set "$ref.age" "$2" #you can use object notation

        unset _error
        _r="$ref" #return the object reference
    }

    MyClass.Greet(){
        local ref="$1"
        if ! o.Has "$ref" name; then
            _error="MyClass.Greet: object '$ref' does not have a 'name' property"
            return 1
        fi
        echo "Hello, $(o.Get "$ref" name)!"
    }


# Example of using the class
    MyClass.New "Rafael" 30; local instance="$_r"
    if [ ! -z "$_error" ]; then
        echo "Error creating MyClass instance: $_error"
        exit 1
    fi

    if o.Implements "$instance" IGreeter; then
        o.Call "$instance.Greet"

        myClass.Greet "$instance" # also works. In this case, the function is called directly.
    else
        echo "MyClass does not implement IGreeter: $_error"
        exit 1
    fi
```

# SHU Misc
The SHU misc library is automatically downloaded and sourced when you run the 'shu init' command. Also, when you create a file using the 'shu touch' command, it will automatically source the misc library, allowing you to use its functions in your scripts.

The misc library is the most important library of SHU Framework, and allow a lot of useful features, such as:
* Object manipulation functions (o.New, o.Get, o.Set, o.Has, o.Delete
* Error printing
* the 'import' command


## Import command
The import command is a function that allows you to easily source files from packages. It does some magic tricks and telepathies to try to guess where the package files are located, that is inside .shu folder :p.

Import will look inside .shu folder for packages and files and, if you pass the argument '--allow-subpackages', it will also look inside .shu folders of the packages.
    


# More about SHU
## Shu command line
The shu command line is a shellscript framework and package manager for shellsripting. It allows programmers to easily user schellscript based packages, as well as to create their own packages and share them with others.

Shu contains commands to retrieve packages for you shellscripts projects, to install packages in your system and much more. 

Shu command line was inspired by 'go command line'.

## Shu Projet structure
    ./shu.yaml  -> shu information
    ./.shu      -> shu cache

## Some conventions
Bashscripts are a well know limitation for conventional programming. For example, function returns are projected to return error codes, instead of values. To lead with it, shu uses some conventions to make it easier to work with shell scripts:

* _r: The variable _r is used to return values from functions. It is a convention that allows you to avoid spawning subshells and makes it easier to work with shell scripts.
* _r2, _r..., _rN: Adicional returns, for multiple returns. Do not forget to uset the variables do prevent memory leaks.
* _r_[name]: named return codes. Do not forget to uset the variables do prevent memory leaks.
* _error: The variable _error is used to return error messages from functions. Should ever follow the conventional error code returning.
## Shu commands

### shu init
```bash
shu ini <projectName>
```
Initializes a shu project in the current folder. It creates a shu.yaml file, runs 'shu get shu-misc' and creates a file called 'main.sh' with a simple example of how to use shu.

This command is not mandatory, and the shu files will be created if when you call other shu commands, but it is utils when you want to start a new project with a simple example.

the 'name' parameter is optional, and if it is not present, the current folder name will be used as project name.

### shu touch
```bash
shu touch <file[.sh]> [options]
options:
    --addmain: Add the file to the 'main' section of shu.yaml.
```
Creates a new script in the current project. If you specify a name with no .sh extension, it will be added automatically. If you want to add the file to the 'main' section of shu.yaml, you can use the --addmain option.

The new will file will be generated with a line sourcing the shu-misc package, allowing you to use basic shu commands in your script.

### shu mainfile sub-cli
Shu projects can have one or more main files. Manage it requires some commands that we decided to group in a sub-command called 'mainfile'.

#### shu mainfile add 'file'
Add 'file' to the 'main' section of shu.yaml file. If shu.yaml does not exists, it will be created. If 'file' is a list, all files will be added to the 'main' section.

#### shu mainfile remove 'file'
Remove 'file' from the 'main' section of shu.yaml file. If shu.yaml does not exists, it will be created. If 'file' is a list, all files will be removed from the 'main' section.

#### shu mainfile list
List all files in the 'main' section of shu.yaml file. If shu.yaml does not exists, it will be created.

#### shu mainfile run [file]
* if .shu folder does not exists, run 'shu restore'
* Run the [file] or read shu.yaml and run all files specified by 'shu addmain'
> You can use shu run, that is an alias for 'shu mainfile run' inspirated by 'go run' command.

### shu run
Shu run is an alias for 'shu mainfile run'. It is used to run the main files of the current project. If no file is specified, it will run all files in the 'main' section of shu.yaml file. It was inspired by the 'go run' command.

### shu dep sub-cli
As ocurros with 'shu mainfiles', manage dependencies also requires some commands that wi decided to group in a sub-command called 'dep'.

#### shu dep add 'package'[@version][#/path/to/folder]
Installs (clones) a package in the current project:

* run 'git clone 'package' ./.shu/packages/'package'
* run 'shu restore inside ./.shu/packages/'package'
* if [@version] is present, run 'git checkout @version'
* if [#/path/to/folder/ is present, only the subfolder 'path/to/folder' will be cloned.

> you can use 'shu get', that is an alias for 'shu dep add' inspirated by 'go get' command.


#### shu dep remove
Removes a package from the current project:
* removes the package from the 'deps' section of shu.yaml file
* removes the package folder from ./.shu/packages/'package'

#### shu dep list
Lists all packages in the 'deps' section of shu.yaml file. 

### shu get
Shu get is an alias for 'shu dep add'. It is used to retrieve a package and add it to the 'deps' section of shu.yaml file. If the package is already present, it will not be added again. The 'shu get' command was inspired by the 'go get' command, and it is used to retrieve packages. But, unlink 'go get', the packages are installed in you project instead of in your system.


### shu restore
read all 'deps' on 'shu.yaml' file and run 'shu get "dep"' for each dependency

### shu install 'package'
* run "git clone 'package' ~/.local/shu/installed/'package'"
* run "shu restore" in ~/.local/shu/installed/'package'
* read ~/.local/shu/installed/'package'/shu.yaml and create symbolic links for all 'main' files, making it available in you system. The symbolic links are put in ~/.local/shu/bin
* ~/.local/shu/bin are added to you PATH (.bashrc will be changed)

#### shu install .
Install the current project in your system.

### shu uninstall 'package'
Uninstalls a package from your system. It removes the symbolic links created by 'shu install', and removes the package from ~/.local/shu/installed.

## inside scripts
### shu.source 'package'
source all 'package'/shu.yaml 'main' files

### shu.source 'package' -f 'main.sh'
source 'main.sh' file from 'package' folder

```yaml
# shu.yaml example
project: shu-example

main:
  - main.sh

deps:
    - obj #looks in 'shu repository'
    - http://git/repository/url.git@aabbcc #looks in 'git repository'
    - http://git/repository/url.git@aabbcc#path/to/subfolder #looks in 'git repository'
```

```bash
    shu get shu-misc #enable shu misc commands (needs 'source ./.shu/packages/shu-misc/shu-misc.sh' in your script)

    shu get logger #recursivelly will get 'obj' package and 'shu-misc' package
```

```bash
    #/!/bin/bash
    source "$(dirname "${BASH_SOURCE[0]}")/.shu/packages/shu-misc/shu-misc.sh"

    shu.source logger


    logger.New; logmanager="$_r"
    o.Call '$logmanager.GetNLog' 'main'; log="$_r"

    o.Call '$log.info' 'info message'

```
[ ] Run shu cmddep check after get a package or restoring project
[ ] Create an alias named 'alias' and redirect it to project_commands (git uses alias and is very nice.. and it is the same funcionality as project_commands)