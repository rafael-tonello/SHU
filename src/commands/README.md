# Command files

Command files extends SHU functionalitty by adding new commands to it.

These files have some attention points:
    
* the filename must be the command name
* the files will be sourced with arguments passed to the command (command itself is removed by shu)
* should attend command help by printing a help message. Help can be requested via '-h', '--help' or 'help' as value of the first argument
* should attend command completion via COMPREPLY or _r variable. Bash completion is requested by shu-cli.sh by passing 'bashCompletion' as first argument
* should not print errors, returnig it via _error variable instead


* all commands are execute in the root of the shu project (if in a shu project)
* pcommands should use stderr to inform erros
* shu hooks should use stderr to inform errors
