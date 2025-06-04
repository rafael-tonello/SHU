# Shu: A Shell Script Framework and Package Manager
# What is Shu?
Shu is a shell script framework and package manager that makes it easy to write and share shell scripts. It provides a simple way to manage dependencies, install packages, and run scripts.

# Getting Started
Install Shu
To install Shu, simply clone this repository and add the shu script to your system's PATH.

```bash
git clone https://github.com/your-username/shu.git
cd shu
sudo cp shu /usr/local/bin/
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

## Example Use Case
Here's an example of how to use Shu to write a simple script:

```bash
# Initialize a new project
shu init myscript

# Add a dependency
shu get logger

# Write a script
echo "logger.info 'Hello World!'" > main.sh

# Run the script
shu run
```
This will create a new project called myscript, add the logger package as a dependency, write a simple script that uses the logger package, and run the script.

#Contributing
Contributions are welcome! If you'd like to contribute to Shu, please fork this repository and submit a pull request.

#License
Shu is licensed under the MIT License.




# More about SHU
## Shu command line
The shu command line is a shellscript framework and package manager for shellsripting. It allows programmers to easily user schellscript based packages, as well as to create their own packages and share them with others.

Shu contains commands to retrieve packages for you shellscripts projects, to install packages in your system and much more. 

Shu command line was inspired by 'go command line'.

## Shu Projet structure
    ./shu.yaml  -> shu information
    ./.shu      -> shu cache


## Shu commands

### shu init [name]
Initializes a shu project in the current folder. It creates a shu.yaml file, runs 'shu get shu-misc' and creates a file called 'main.sh' with a simple example of how to use shu.

This command is not mandatory, and the shu files will be created if when you call other shu commands, but it is utils when you want to start a new project with a simple example.

the 'name' parameter is optional, and if it is not present, the current folder name will be used as project name.

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
    source ./.shu/packages/shu-misc/shu-misc.sh

    shu.source logger


    logger.New; logmanager="$_r"
    o.Call '$logmanager.GetNLog' 'main'; log="$_r"

    o.Call '$log.info' 'info message'

```