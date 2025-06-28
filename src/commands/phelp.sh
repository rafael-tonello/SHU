#!/bin/bash

#manages special help texts for the project.

shu.phelp.Add(){ 
    :;
}

shu.phelp.Help(){
    echo "phelp <subcommand>       - Manage project help texts that are displayed by 'shu --help' and 'shu -h'. It allows you to add, remove and list help texts specifics for your project. These help texts are intended to provide additional information about your project, its commands, and how to use them effectively. You can highlight parts of the text by using some markers (note that the terminal where the help is dipslayed should support ANSI colors to display. Colors can be different depending on the terminal, but the markers are the same). The help messages are displayed at the end of the 'shu --help' text."

    echo "  subcommands:"
    echo "    add <name> <text[marker]more text[/]>     - Add a new help text with the specified name and text."
    echo "      markers:"
    echo "        [red]...[/] - A red text between these markers."
    echo "        [green]...[/] - A green text between these markers."
    echo "        [yellow]...[/] - A yellow text."
    echo "        [blue]...[/] - A blue text."
    echo "        [magenta]...[/] - Magenta text."
    echo "        [cyan]...[/] - Cyan text."
    echo "        [white]...[/] - White text."
    echo "        [bold]...[/] - Bold the text between these markers."
    echo "        [underline]...[/] - Underline the text between these markers."
    echo "        [italic]...[/] - Italicize the text between these markers."
    echo "    remove <name>         - Remove a help text by its name."
    echo "    list                  - List all help texts in the project."
}