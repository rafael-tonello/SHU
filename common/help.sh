#!/bin/bash

# example usage:
#   Help.New "MyApp Help" 20 "Usage: $0 <command> [args...]" "Available commands:"; local helpObj="$_r"
#   o.Call "$helpObj.Add" "init" "<config-file>" "Initializes the application with the specified configuration file."
#   o.Call "$helpObj.Add" "start" "<service-name>" "Starts the specified service."
#   o.Call "$helpObj.Add" "stop" "<service-name>" "Stops the specified service."
#   o.Call "$helpObj.Print" "$helpObj"

# Initializes a new help object with title, indentation size, usage tip, and command prefix
# Parameters:
#   title: Main title for the help section
#   identSize: Indentation size for command listings (default 20)
#   usageTip: Usage tip text (default: "Usage: $0 <command> [args...]"
#   commandSessionPrefix: Prefix for listing available commands
# Returns: Help object with configuration
Help.New(){
    local title=$1;
    local identSize=${2:-"20"};
    local usageTip=${3:-"Usage: $0 <command> [args...]"};
    local commandSessionPrefix=${4:-"Available commands:"};
    o.New Help; local ret=$_r
    o.Set "$ret.title" "$title"
    o.Set "$ret.usageTip" "$usageTip"
    o.Set "$ret.identSize" "$identSize"
    o.Set "$ret.commandSessionPrefix" "$commandSessionPrefix"

    o.Set "$ret.itemCount" 0

    _r="$ret"
}

# Adds an entry to the help object
# Parameters:
#   help: Help object to modify
#   cmd: Command name
#   args: Argument description
#   text: Help text for the command
# Appends a new item to the help object's command list
Help.Add(){
 local help=$1; local cmd=$2; local args=$3; local text=$4;
    o.Get "$help.itemCount"; local itemCount=$_r

    o.Set "$help.$itemCount.cmd" "$cmd"
    o.Set "$help.$itemCount.helpArgs" "$args"
    o.Set "$help.$itemCount.helpText" "$text"
    o.Set "$help.itemCount" $(( itemCount + 1 ))
}

# Prints the formatted help information
# Parameters:
#   help: Help object containing configuration and command entries
# Formats and displays the help text with appropriate indentation and wrapping
# Handles terminal width detection and text wrapping
Help.Print(){
  local help=$1
    o.Get "$help.identSize"; local identSize=$_r
    o.Get "$help.title"; local title=$_r
    o.Get "$help.usageTip"; local usageTip=$_r
    o.Get "$help.commandSessionPrefix"; local commandSessionPrefix=$_r

    local terminalWidth=$(tput cols)
    if [ $terminalWidth -gt 120 ]; then
        #try via stty size, if fails, set to 120
        terminalWidth=$(stty size 2> /dev/null | awk '{print $2}')
        if [ -z "$terminalWidth" ]; then
            terminalWidth=100
        fi
    fi


    echo "$title"
    echo ""
    echo "$usageTip"
    echo ""
    echo "$commandSessionPrefix"

    o.Get "$help.itemCount"; local itemCount=$_r

    for (( i=0; i<itemCount; i++ )); do
        o.Get "$help.$i.cmd"; local cmd="$_r"
        o.Get "$help.$i.helpArgs"; local helpArgs="$_r"
        o.Get "$help.$i.helpText"; local helpText="$_r"

        local boldCmd="\033[1m$cmd\033[0m"
        local italicHelpArgs="\033[3m$helpArgs\033[0m"

        local header="$boldCmd $italicHelpArgs"
        local headerNoFormat="$cmd $helpArgs"

        local totalHeaderSize=$(( ${#headerNoFormat} + 1 ))
        local identText="$(printf "%*s" "$((identSize + 3))" " ")"

        if [ "$totalHeaderSize" -lt $identSize ]; then
            helpText="$(printf "  %-${identSize}s" "$header ") $helpText"
        else
            printf "  $header\n"
        fi

        #spit by '\n' string (not the char) to get idividual lines
        
        local linesArr=()
        while true; do
            if [[ "$helpText" == *"\n"* ]]; then
                linesArr+=("${helpText%%\\n*}")
                helpText="${helpText#*\\n}"
            else
                linesArr+=("$helpText")
                break
            fi
        done


        for line in "${linesArr[@]}"; do
            #check if line is not the header
            if [[ "$line" != *"$header"* ]]; then
                line="$identText$line"
            fi

            while true; do
                #break only on space or end of line, to avoid cutting words
                local cutPosition=$terminalWidth
                while true; do
                    charAtCutPos=$(echo "$line" | cut -c$cutPosition)
                    if [ "$charAtCutPos" == " " ] || [ "$charAtCutPos" == "" ]; then
                        break;
                    fi
                    cutPosition=$((cutPosition - 1))
                done

                toPrint=$(echo "$line" | cut -c1-$cutPosition)
                line="${line:$cutPosition}"
                #trim start
                line="${line#"${line%%[![:space:]]*}"}"

                printf "$toPrint\n"

                if [ -z "$line" ]; then
                    break
                fi

                line="$identText $line"
            done
        done
            
        #if [ ! -z "${!helpVar}" ]; then
        #    printf "  %-20s %s\n\n" "$cmd ${!helpArgsVar}" "${!helpVar}"
        #fi

        echo ""
    done
    echo ""
}
#}
