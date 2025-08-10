# SHU (Shell Script Utils)

**SHU** is a command-line tool that acts as a **package manager**, **automation system**, and **shell scripting framework** for software projects.

# Table of Contents
- [Overview](#overview)
- [Key Features](#key-features)
- [Installation](#installation)
- [Getting Started](#getting-started)
  - [Initialize a New Project](#1-initialize-a-new-project)
  - [Add a Dependency](#2-add-a-dependency)
  - [Add a Hook](#3-add-a-hook)
  - [Project Commands](#4-project-commands)
- [Concepts](#concepts)
  - [Project Initialization](#1-project-initialization)
  - [Dependencies](#2-dependencies)
  - [Project Commands](#3-project-commands)
  - [Hooks](#4-hooks)
  - [Properties](#5-properties)
  - [System Dependencies](#6-system-dependencies)
  - [Main Script Handling](#7-main-script-handling-deprecated)
  - [Built-in Shell Script Framework](#8-built-in-shell-script-framework)
- [Project Initialization](#project-initialization)
  - [Create a New Project](#1-create-a-new-project)
  - [Using a Template](#2-using-a-template)
  - [shu.yaml Overview](#3-shuyaml-overview)
  - [Reinitializing or Resetting](#4-reinitializing-or-resetting)
- [Managing Dependencies](#managing-dependencies)
  - [Add a Dependency](#1-add-a-dependency)
  - [Restore Dependencies](#2-restore-dependencies)
  - [Clean Dependencies](#3-clean-dependencies)
- [Shu CLI Help text](#shu-cli-help-text)

# Overview

Originally designed for shell scripting, SHU has evolved into a powerful tool to **automate, organize, and scale any kind of software project** — whether it’s a shell-based tool, a C++ server, or a hybrid system.

At its core, SHU helps you:

- Manage packages from Git or archive sources
- Define and run project-specific CLI commands
- Hook actions before or after commands (for automation)
- Write structured and reusable shell automation scripts

It also includes a **built-in shell scripting framework** — specifically designed for:
- Writing project automation logic
- Building server-side workflows
- Creating modular, object-oriented Bash code
- Scheduling periodic tasks, monitoring git state, and more

Whether you're managing deployment tasks, writing helper commands, or wiring up build pipelines, SHU provides structure and extensibility for your project’s automation needs.


# Key Features

- 🧩 **Package Management**  
  Fetch project dependencies from Git or archive URLs with fine control over path, branch, and naming. Restore and clean them with ease.

- ⚙️ **Project Commands**  
  Define CLI commands specific to your project using Bash scripts, integrated with SHU’s command system.

- 🔁 **Hooks System**  
  Automate actions before or after any SHU or project command — ideal for installing Git hooks, post-build steps, deployment, etc.

- 📦 **Template-Based Initialization**  
  Start projects from Git repos or archive templates, supporting selective folder extraction and recursive dependency restore.

- 🧪 **Built-in Test Runner**  
  Locate and execute `.tests.sh` files across your project for quick and automated testing.

- 📁 **Main Script Handling**  
  Define entry points for running or building your project with `shu run` or `shu build`.

- 🧠 **Project Properties System**  
  Store and access custom key-value config and structured data within your `shu.yaml`.

- 🔐 **System Dependency Declaration**  
  Declare and validate required system binaries for your project to function properly.

- 🐚 **Shell Script Framework (OOP in Shell!)**  
  Bring object-orientation, interfaces, logging, scheduling, streams, and more to shell scripts.

---

# Installation

To install SHU on your system, just run the following command:

```bash
curl -sSL https://raw.githubusercontent.com/rafael-tonello/SHU/main/src/tools/shu-install.sh | bash
```
This script will:

* Download the latest version of SHU from the official repository

* Place it in your $HOME/.local/bin (or a custom path if set)

* Ensure it’s executable and available in your terminal

After installation, you can verify it's working:
```bash
shu --version
```

If everything is set up correctly, you'll see the current SHU version printed.


# 🚀 Getting Started
This section will guide you through the basic usage of SHU (Shell Script Utils) — from initializing a project to running your first hook and project commands.

## 1. Initialize a New Project
To create a new SHU project in your current directory:

```bash
shu init
```

Or specify a project name:

```bash
shu init MyProject
```
💡 This will create a .shu/ directory and a shu.yaml file to configure your project.



## 2. Add a Dependency
SHU allows you to easily include reusable components, templates, or libraries as dependencies:

```bash
shu get https://github.com/rafael-tonello/SHU.git@main#/src/libs/shu-common
```
This installs the dependency into .shu/deps/ and makes its components available in your project.

## 🔗 3. Add a Hook

SHU includes a built-in command for managing hooks — no need to edit `shu.yaml` manually.

A hook lets you run a command **before** or **after** a specific SHU command is executed (including your own custom project commands).

---

### ➕ Add a New Hook

The syntax is:

```bash
shu hooks add <when> <shu-command> <command>
```
* \<when\> - Either before or after the target SHU command.

* \<shu-command\> - The command that triggers the hook (without the shu prefix).

* \<command\> - The Bash command or script to run.

For scripts that need access to SHU’s memory context, use source ./yourscript.sh instead of ./yourscript.sh.


#### Example: Run a script after a dependency is installed
```bash
mkdir -p scripts
echo -e '#!/bin/bash\necho "Post-installation script triggered!"' > scripts/after-install.sh
chmod +x scripts/after-install.sh

shu hooks add after "get" " ./scripts/after-install.sh"
```

Now, whenever you run `shu get`, the `after-install.sh` script will execute after the dependency is fetched.

## 🛠️ 4. Project Commands

SHU allows you to define **custom project commands** so your team can run automation tasks in a consistent way — without needing to remember long Bash commands.

Project commands are managed with:

```bash
shu pcommand <subcommand>
```

### ➕ Add a Project Command
```bash
shu pcommand add <name> <command> <description>
```
* <name> — The name you’ll use to run the command (e.g., build → shu build).

* <command> — The Bash command or script to execute.

* <description> — A short description shown in shu --help.

Example:

```bash
shu pcommand add build "bash scripts/build.sh" "Build the project"
```
After adding it:

```bash
shu build
```
will run bash scripts/build.sh.

### 📋 List Project Commands
```bash
shu pcommand list
```
Options:
* --one-line — Display each command in a single line.
* callback <callback> — Call a custom callback script for each command (receives <name> <command> <description>).

### ❌ Remove a Project Command
```bash
shu pcommand remove <name>
```

### ▶️ Run a Project Command Manually
While you can simply run shu <name>, you can also explicitly call:

```bash
shu pcommand run <name> [args...]
```

# 📚 Concepts

Before diving deeper into SHU’s commands, it’s important to understand the core concepts that make up a SHU-powered project.  
These ideas define how SHU organizes automation, manages dependencies, and structures shell scripting.

---

## 1. Project Initialization
Every SHU project is defined by a `.shu/` directory and a `shu.yaml` configuration file.  
Initialization sets up the foundation for:

- Tracking dependencies
- Registering project commands
- Storing hooks
- Managing project properties

Once initialized, you can start adding automation and dependencies without manually editing `shu.yaml`.

---

## 2. Dependencies
SHU treats **dependencies** as reusable packages — they can be shell libraries, templates, or entire projects.  

- **Source types:** Git repositories, local folders, or archive files (tar, zip).
- **Location:** Stored in `.shu/deps/` and referenced by your scripts.
- **Restore/Clean:** You can re-fetch all dependencies or remove them entirely when needed.

Dependencies make it easy to share reusable scripts and automation logic across multiple projects.

---

## 3. Project Commands
Instead of remembering long shell commands, SHU lets you define **named commands** for your project.  
Example:  
```bash
shu build
```
…could run a complex build script without the developer needing to know its exact path or parameters.

### Project commands:

* Have a name, a command, and a description

* Are stored in your project configuration

* Can be listed, removed, or run explicitly

## 4. Hooks
Hooks are automation triggers that run before or after specific SHU or project commands.

Examples:

prints a message after the build command
```bash
shu hooks add after build "echo 'Build completed!'"
```
runs tests before the build command
```bash
shu hooks add before build "shu tests --run"
```
Deploy artifacts after shu install
```bash
shu hooks add after install "bash scripts/deploy.sh"
```


You can hook into any SHU command (including custom ones) without modifying the command itself.

## 5. Properties
Properties are key-value settings stored in shu.yaml.
They allow you to define configuration values that your scripts can read at runtime — for example:

API keys

Project metadata

Environment-specific values (should/can be loaded by your scripts)

Properties keep your scripts flexible and configurable.

## 6. System Dependencies
System dependencies are binaries or tools your project requires to function (e.g., git, make, docker).
You can declare them in SHU so that it automatically checks they exist before running some of your project commands (like shu init and shu restore).

Examples:
```bash
#adding git as a required system dependency
shu psysdeps add git "Git is required for fetching dependencies"
```
This ensures that anyone working on your project has the necessary tools installed.

```bash
#checking if all system dependencies are met
shu psysdeps check
```
This will verify that all declared system dependencies are available.

```bash
#listing all declared system dependencies
shu psysdeps list
```
This will show all the system dependencies your project requires.


## 7. Main Script Handling (deprecated)
SHU supports defining a main file (or entry point) for your project.
This is what runs when you execute:

```bash
shu run
```

```bash
shu build
```
This standardizes how developers interact with your project.

## 8. Built-in Shell Script Framework
SHU includes an Object-Oriented Shell Scripting Framework with utilities like:

* Classes & interfaces
* Logger and stream handling
* Scheduler for periodic tasks
* Git monitor for repository changes
* Prebuilt utility libraries


This framework enables you to write large, structured shell-based automation without the chaos of ad-hoc scripts.

# 📂 Project Initialization

Initializing a SHU project sets up the base structure and configuration files so you can start managing dependencies, hooks, and automation scripts right away.

## 1. Create a New Project
To initialize SHU in your current directory:

```bash
shu init
```

```bash
shu init MyProject
```
This will:

*Create a .shu/ directory for SHU’s internal data
*Generate a shu.yaml configuration file
*Prepare empty folders for dependencies and scripts

## 2. Using a Template
You can initialize a project from a Git repository or an archive (e.g., .tar.gz, .zip):

```bash
shu init https://github.com/username/project-template.git
```
You can also point to a subdirectory in the template:

```bash
shu init https://github.com/username/project-template.git#/template/subdir
```
This is useful for starting with a pre-built structure, boilerplate code, or a company-specific setup.

## 3. shu.yaml Overview
After initialization, your shu.yaml will contain the basic project configuration:

```yaml
name: MyProject
version: 0.1.0
description: ""
dependencies: []
hooks: []
properties: {}
```
You can edit this file manually, but most settings can be managed using SHU commands (pdeps, pcommand, hooks, etc.).

## 4. Reinitializing or Resetting
If you want to reset SHU’s internal data without touching your source code:

```bash
shu init --force
```
⚠ Warning: This may overwrite your .shu/ folder and shu.yaml, so make backups if needed.

# 📦 Managing Dependencies

SHU includes a built-in package management system that lets you fetch, update, and remove project dependencies from Git repositories or archive files.

## 1. Add a Dependency
To fetch a dependency:

```text
shu get <source>[@<ref>][#<subdir>] [as <custom-name>]

shu pdeps get <source>[@<ref>][#<subdir>] [as <custom-name>]
```
* \<source\> — URL to a Git repository or archive file

* \@\<ref\> — Optional Git branch, tag, or commit (defaults to main)

* \#\<subdir\> — Optional subdirectory to extract from the source

* as \<custom-name\> — Custom name for the dependency folder (optional)

Example:

```text
shu pdeps add https://github.com/rafael-tonello/SHU.git@main#/src/libs/shu-common
```
This installs the shu-common library into .shu/deps/.

## 2. Restore Dependencies
If you cloned a SHU project and need to fetch all declared dependencies:

```bash
shu pdeps restore
```
This reads the dependencies: section in shu.yaml and downloads everything.


## 3. Clean Dependencies
To remove all installed dependencies without editing shu.yaml:

```bash
shu pdeps clean
```
💡 Tips:

- Dependencies are stored in .shu/deps/ and isolated from your source code.
- You can point dependencies to private Git repositories if your SSH keys are set up.
- Using subdirectories in dependencies helps reduce bloat when fetching large repos.

# Shu   CLI Help text
```text
Shu CLI version 0.1.0 - A package manager and project automation system.
Usage:
  shu <command> [options]

Shu commands:
  init [projectName] [options]
                           - Initialize a new Shu project in the current directory.
    options:
      --template "<url[@<checkout_to>][#<path>][--allow-no-git]>" [options]
                             - Use a previus shu project as a template to initialize the
                                current folder. The template can be a git repository, a file
                                URL (zip, 7z, tar.gz, tar.bz2) or a directory. Internaly, this
                                will use 'shu pdeps get' command to get the template.'
      options:
        --not-recursive        - Do not restore dependencies of the package.
      @<checkout_to>         - Shu will checkout the repository to <checkout_to>.
      #<path>                - Shu will copy only the contents of the specified path (in the
                                repository) to the package folder.
      --allow-no-git         - allow a no git repository. Shu will try to find it in the
                                filesystem or download it from the web. If a download could be
                                done, the shu will try to extract it if has a supported
                                extension (.zip, .tar.gz, .tar.bz2, .7z).
  touch <scriptName>...    - Create a new .sh file with a basic structure.
  get <urls>...            - Get one or more packages from Git URL and add it to the project.
                              redirects to 'shu pdeps get <url>' (see int the 'pdeps'
                              subcommand).
  clean                    - Remove the .shu folder and all installed packages.
  restore                  - Restore all dependencies from shu.yaml.
  refresh                  - Clean and restore all dependencies from shu.yaml.
  setmain <scriptName>     - Set a script as the main script for the project.
  run [scriptName]         - Run the main script or a specific script.
  install <url>            - Install a package from a URL to your system. Note that this
                              command will install to be executed in your system, and not in
                              your project. It is used to install projects written with SHU.
                              Redirects to 'shu installer install'
  uninstall <packageOrCommandName>
                           - Uninstall a package or command from your sytem. Note that this
                              command will not operate in your project, but in packages
                              installed in your system via 'shu install'. Redirects to 'shu
                              installer uninstall'
  pcommand <subcommand>    - Commands to manage dependencies of the project
    subcommands:
      add <name> <command> <description>
                             - Add a new command to the project. When you run 'shu <name>', the
                                bash command <command> will be executed. All arguments will be
                                passed to the command. When you run 'shu --help', the
                                <discription> will be shown as description of the command.
                                <name>, <command> and <description> are required parameters.
      list [callback | options]
                             - List all project commands.
        callback <callback>    - If provided, the callback will be called with the command
                                  name, action and description as arguments instead of printing
                                  the commands to the console.
        options:
          --one-line           - Use only one line to each command.
      remove <command>       - Removes the project the project command <command>.
      run  <command> [args]  - Runs the command <command> and pass [args] to it. Is the same as
                                running 'shu <command> [args]'.
    runtool <scriptName>   - Find scripts named <scriptName> in ./shu/packages/ and run them.
                              Internally, it uses 'find' (in a recusive way) to find the
                              desired script and, if it be able to find that, runs it.
  hooks <subcommand>        - Manage hooks for shu commands. Is focused in automating the
                               project. A hooks runs commands before or after a shu command be
                               executed (including those ones created for your project. See
                               'shu pcommand --help' for more information).
    subcommands:
      add <when> <shu-command> <command>
                               - Add a new hooks than executes <command> <when> <shu-command>.
                                  <command> is a shu command without the 'shu' prefix. For
                                  example, 'add before build' will add a hooks that executes
                                  'build' command before the <shu-command> is executed.
                                  <command> is a bash command. You can specify commands
                                  directly or use a script file. If you want to use a script,
                                  and want that this script have access to shu memory context,
                                  you should use 'source <your script>' instead of '<your
                                  script.sh>. The <when> can be 'after' or 'before' (more
                                  information below).
        when:                  - Sepcify when, relative to the shu command, the hooks should be
                                  executed.
          before                 - hooks should be executed before the <shu-command> be
                                    executed. If return code is not 0, the <shu-command> will
                                    not be executed.
          after                  - hooks should be executed after the <shu-command> be
                                    executed.
        shu-command:           - The shu command that will trigger the hooks. It a command,
                                  that shu is running, starts with this shu-command, the hooks
                                  will be executed.
        command:               - The command to be executed when the hooks is triggered. It can
                                  be a bash command or a script file. If it is a script file,
                                  you should use 'source <your script>' to have access to shu
                                  memory context. Before a hooks be executed, shu export some
                                  variables that can be used in you command/script:
                                  1) SHU_HOOK_INDEX: the index of the hooks in the list of
                                     hooks.
                                  2) SHU_HOOK_WHEN: when the hooks is execute (before or after)
                                     in relation to the shu command.
                                  3) SHU_HOOK_COMMAND_TO_RUN: the hooks commnad (your code).
                                  4) SHU_HOOK_COMMAND_TO_CHECK: the shu command that should be
                                     evaluated.
                                  5) SHU_HOOK_RECEIVED_COMMAND: the command that is being
                                     executed (the command that shu is running).
      list [callback]        - List all hooks in the project.
        callback:             - If provided, the callback will be called for each hooks with
                                 the following arguments: <index> <when> <shu-command>
                                 <command>. If not provided, the hooks will be printed to the
                                 console.
      remove <index>         - Remove a hooks by its index from the list of hooks.
  mainfile <subcommand>    - Commands to manage main scripts of the project
    subcommands:
      add <scriptNames>...     - Add scripts to the main section of shu.yaml.
      remove <scriptNames>...
                               - Remove scripts from the main section of shu.yaml.
    list                     - List all scripts in the main section of shu.yaml.
  tests [what] [options]    - Finds tests files and runs them. Tests files are files with the
                               '.tests' sequence in its name. If you provide a file without
                               '.tests', shu will try to find it by putting '.tests.' between
                               filename and its extension. If nothing was provided (no
                               arguments), shu will assume the current folder as directory.
    what                     - You can specify a filename or a directory. Using a file name, it
                                will runs only the specified tests file. Using a direcotry, it
                                will run all tests files in the directory
    options:
     --recursive, -r           - If you provide a directory, shu will run tests in all
                                  subdirectories recursively.
  touch <fileName>         - Create a new script file with the given name. If no extension is
                              provided, .sh will be added.
  pdeps <subcommand>         - Commands to manage dependencies of the project
    subcommands:
      get "<url[@<checkout_to>][#<path>][as <name>][pack options]>"
                             - Get a package from a URL and add it to the project. If you are
                                hooking this command (after the execution), it exports
                                SHU_LAST_DEP_GET_FOLDER with the path to the package folder.
                                Attention: pack options should be passed inside "" among the
                                dependency url.
        @<checkout_to>         - Shu will checkout the repository to <checkout_to>.
        #<path>                - Shu will copy only the contents of the specified path (in the
                                  repository) to the package folder.
        as <name>              - Shu will name package folder to <name> instead of the
                                  repository name.
        pack options:
          --allow-no-git         - allow a no git repository. Shu will try to find it in the
                                    filesystem or download it from the web. If a download could
                                    be done, the shu will try to extract it if has a supported
                                    extension (.zip, .tar.gz, .tar.bz2, .7z).
          --not-recursive        - Do not restore dependencies of the package.
          --git-recursive-clone  - Use git clone --recursive to clone the repository. If the
                                    repository is not a git repository, it will be ignored.
      restore                - Restore all dependencies from shu.yaml.
      list [callback]        - List all dependencies in the project. If callback is provided,
                                it will be called with the dependency as argument.
        callback:              - If provided, the callback will be called for each dependency
                                  with the dependency as argument. If not provided, the
                                  dependencies will be printed to the console.
      clean                  - Remove all dependencies from shu.yaml.
    examples:
      shu pdeps get 'https://github.com/rafael-tonello/SHU.git'
                             - Get the SHU package from GitHub and add it to the project.
      shu pdeps get 'https://github.com/rafael-tonello/SHU.git@develop --not-recursive'
                             - Get the SHU package from GitHub, checkout to develop branch and
                                do not restore dependencies.
      shu pdeps get
  'https://github.com/rafael-tonello/SHU.git@develop#/src/shellscript-fw/common
                             - Get the SHU package from GitHub, checkout to develop branch,
                                copy only the contents of src/shellscript-fw/common to the
                                package folder.
  build                    - Build a shellscript project. Compile the project in a single .sh
                              file. This command is focused on shellscript projects, and you
                              can override it through 'shu pcommand' subcommands. See 'shu
                              pcommand --help' for more information.
  pprops <subcommand>      - Manage project properties, data and key-value infomation. These
                              properties are key-value pairs stored in the 'shu.yaml' file of
                              the project, and allow you to store data and states for your
                              project automation or whatever you want :D . They can be used to
                              store configuration values, settings, or any other data related
                              to the project. You can use object notation in 'keys', so you can
                              store structured data.
    subcommands:
      set <key> <value>     - Set a property with the specified key and value. You can set
                               multiple properties at once by providing multiple key-value
                               pairs.
      get <key>             - Get the value of a property by its key.
      list [callback]       - List all properties of the project.
        callback:             - If provided, the callback will be called for each property with
                                 the key and value as arguments. If not provided, the
                                 properties will be printed to the console.
      remove <key>          - Remove a property by its key.
      addarrayitem <arrayKey> <value> - Add an item to an array property.
      listarrayitems <arrayKey>
                            - List items of an array property.
      removearrayitem <arrayKey> <index> - Remove an item from an array property by index.
      addarrayobject <arrayKey> [key:value]... - Add an object to an array property with
                                                  key-value pairs.
      getobjectfromarray <arrayKey> <index> [callback] - Get an object from an array property
                                                          by index and optionally call a
                                                          callback with its key-value pairs.
  psysdeps <subcommand>      - Informs system commands needed to project work correctly.
    subcommands:
      add <commandName> [information] [options]
                             - Add a command to the sysdepss section of shu.yaml.
        options:
          --force, -f          - force to command to be added. It will override the existing
                                  (will update) command.
          --check-command, -c  - changes the way that shu check for dependency. Default way if
                                  using 'command -v <commandName>'
      remove <commandName>   - Remove a command from the sysdepss section of shu.yaml.
      list [callback | options]
                             - List all commands in the sysdepss section of shu.yaml.
        callback:              - If provided, the callback will be called for each command with
                                  the command name, description and check command as
                                  arguments.
        options:
          --level, -l <level>  - specify the level of dependencies to scan. default is 0 (no
                                  limits)
                                 examples:
                                   0 - all dependencies of all packages and the current
                                      project;
                                   1 - only the current project;
                                   2 - current project and its dependencies;
                                   3 - current project and its dependencies and their
                                      dependencies, etc;
                                   N - current project and its dependencies and their
                                      dependencies and so on, up to N levels;
          --onlynames, -on     - only show the names of the dependencies
      check [options]        - Check if the commands in the sysdepss section of shu.yaml are
                                available in the system.
        options:
          --level, -l <level>  - specify the level of dependencies


Additional information about Shu:
  - Shu initially was focused on shellscripting, but it was changed over the time and, now, shu
     can work with (almost) any kind of software project, managing packages from git
     repositories and automating the project with commands, hooks and more.
  - If you are hooking a command or writing commands for you project, shu exports some
     variables:
    - SHU_PROJECT_ROOT_DIR: The root directory of the project. It is the directory where the
       shu.yaml file is located.
    - SHU_PROJECT_WORK_DIR: The current working directory of the project
    - SHU_LAST_DEP_GET_FOLDER: The folder where the last dependency was downloaded. It is only
       available after the 'shu pdeps get' be execute and is designed to be used in hooks.
    - SHU_HOOK_INDEX: When running hooks, contains the index of the hook (in the 'shu.xml'
       hooks list).
    - SHU_HOOK_WHEN: When running hooks, contains the moment when the hook is being executed
       (related to the command being executed). Possible values are 'before' and 'after'.
    - SHU_HOOK_COMMAND_TO_RUN: When running hooks, contains the hooks commnad (your code).
    - SHU_HOOK_COMMAND_TO_CHECK: When running hooks, contains the shu command that should be
       evaluated.
    - SHU_HOOK_RECEIVED_COMMAND: When running hooks, contains the command that is being
       executed (the command that shu is running).
    - SHU_BINARY: The path to the shu binary that is being executed. Useful when using shu
       embedded in a project.
rafinha_tonello@vmware-ubuntu22:~$ 


```