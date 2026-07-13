#!/bin/bash

# example usage:
#   Help.New "MyApp Help" 20 "Usage: $0 <command> [args...]" "Available commands:"; local helpObj="$_r"
#   o.Call "$helpObj.Add" "init" "<config-file>" "Initializes the application with the specified configuration file."
#   o.Call "$helpObj.Add" "start" "<service-name>" "Starts the specified service."
#   o.Call "$helpObj.Add" "stop" "<service-name>" "Stops the specified service."
#   o.Call "$helpObj.Print" "$helpObj"
#   o.Release "$helpObj" true

# Initializes a new help object with title, indentation size, usage tip, and command prefix
# Parameters:
#   title: Main title for the help section
#   identSize: Indentation size for command listings (default 20)
#   usageTip: Usage tip text (default: "Usage: $0 <command> [args...]"
#   commandSessionPrefix: Prefix for listing available commands
# Returns: Help object with configuration

if [ "$SHU_MISC_LOADED" != "true" ]; then
    #red message
    printf "\033[31mError: This library requires the 'misc.sh' library to be loaded first. Please load it before loading this library.\033[0m\n"

    #return if sources
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 1
    fi
    exit 1
fi

Help.New(){
    local title=$1;
    local usageTip=${2:-"  Usage: $0 <command> [args...]"};
    local defaultIdentSize=${3:-"20"};
    local addEmptyLines=${4:-"false"};

    o.New Help; local ret=$_r
    o.Set "$ret.title" "$title"
    o.Set "$ret.usageTip" "$usageTip"
    o.Set "$ret.defaultIdentSize" "$defaultIdentSize"
 
    o.Set "$ret.addEmptyLines" "$addEmptyLines"
 
    o.Set "$ret.sessions.count" 0

    

    _r="$ret"
}

#return session id
Help.AddSession(){
    local help=$1;
    local title=$2;
    local identSize=${3:-""};

    if [ -z "$identSize" ]; then
        o.Get "$help.defaultIdentSize"; local identSize=$_r
    fi
    
    helpSession.New "$help" "$title" "$identSize"; local session="$_r"

    o.Get "$help.sessions.count"; local sessionCount=$_r
    o.Set "$help.sessions.$sessionCount" "$session"
    o.Set "$help.sessions.count" $((sessionCount + 1))

    _r="$session"
    return 0
}

# Prints the formatted help information
# Parameters:
#   help: Help object containing configuration and command entries
# Formats and displays the help text with appropriate indentation and wrapping
# Handles terminal width detection and text wrapping
Help.Print(){
    local help=$1
    o.Get "$help.title"; local title=$_r
    o.Get "$help.usageTip"; local usageTip=$_r
    o.Get "$help.sessions.count"; local sessionCount=$_r
    o.Get "$help.addEmptyLines"; local addEmptyLines=$_r

    echo "$title"
    if [ "$addEmptyLines" == "true" ]; then echo "";  fi
    echo "$usageTip"
    if [ "$addEmptyLines" == "true" ]; then echo "";  fi

    local terminalWidth="${COLUMNS:-}"
    if [ -z "$terminalWidth" ] || [ "$terminalWidth" -le 0 ] 2>/dev/null; then
        terminalWidth=$(tput cols 2> /dev/null)
    fi
    if [ -z "$terminalWidth" ] || [ "$terminalWidth" -le 0 ] 2>/dev/null; then
        terminalWidth=100
    fi

    if [ "$terminalWidth" -gt 120 ]; then
        #try via stty size, if fails, set to 120
        terminalWidth=$(stty size 2> /dev/null | awk '{print $2}')
        if [ -z "$terminalWidth" ]; then
            terminalWidth=100
        fi
    fi

    local i
    for (( i=0; i<sessionCount; i++ )); do
        o.Get "$help.sessions.$i"; local session="$_r"
        o.Call "$session.Print" "$terminalWidth" "$addEmptyLines"
    done
    if [ "$addEmptyLines" == "true" ]; then echo "";  fi
}
#}


helpSession.New(){ local helpObj=$1; local title=$2; local identSize=${3:-"20"}; 
    o.Implements "$helpObj" "Help";
    if [ "$_error" != "" ]; then
        _error="invalid Help object: $_error"
        _r=""
        return 1
    fi

    o.New helpSession; local ret="$_r"
    o.Set "$ret.title" "$title"
    o.Set "$ret.identSize" "$identSize"
    o.Set "$ret.items.count" 0
    o.Set "$ret.controller" "$helpObj"

    _error=""
    _r="$ret"
    return 0
}

# Adds an entry to the help object
# Parameters:
#   help: Help object to modify
#   cmd: Command name
#   args: Argument description
#   text: Help text for the command
# Appends a new item to the help object's command list
helpSession.AddItem(){ local session=$1; local cmd=$2; local args=$3; local text=$4;
    o.Get "$session.items.count"; local itemCount=$_r
    o.Set "$session.items.$itemCount.cmd" "$cmd"
    o.Set "$session.items.$itemCount.helpArgs" "$args"
    o.Set "$session.items.$itemCount.helpText" "$text"
    o.Set "$session.items.count" $(( itemCount + 1 ))
}

helpSession.Print(){ local session=$1; local terminalWidth=$2; local addEmptyLines=$3
    o.Get "$session.title"; local title=$_r
    o.Get "$session.identSize"; local identSize=$_r
    o.Get "$session.items.count"; local itemCount=$_r

    if [ "$title" != "" ]; then
        echo "$title"
        if [ "$addEmptyLines" == "true" ]; then echo "";  fi
    fi

    local i

    for (( i=0; i<itemCount; i++ )); do
        o.Call "$session.printHelpItem" "$session.items.$i" "$terminalWidth" "$identSize" "$addEmptyLines"
    done
}

helpSession.printHelpItem(){ local session=$1; local item=$2; local terminalWidth=$3; local identSize=$4; local addEmptyLines=$5

    o.Get "$item.cmd"; local cmd="$_r"
    o.Get "$item.helpArgs"; local helpArgs="$_r"
    o.Get "$item.helpText"; local helpText="$_r"


    local boldCmd="\033[1m$cmd\033[0m"
    local italicHelpArgs="\033[3m$helpArgs\033[0m"

    local identText
    printf -v identText "%*s" "$((identSize))" ""

    printf "  $boldCmd $italicHelpArgs"
    local lastPrinted="$cmd $helpArgs"
    local col=${#lastPrinted}
    if [ $col -ge $identSize ]; then
        printf "\n"
        col=0
    else 
        #print space until identSize
        while [ $col -lt $identSize ]; do
            printf " "
            col=$((col + 1))
        done
    fi
    while true; do
        if [ "$col" -le 0 ]; then
            printf "$identText  "
            col=$identSize
        fi

        local availableSpace=$(( terminalWidth - col -2 ));

        #cut 'availableSapce' chars from helpText
        local toPrint="${helpText:0:$availableSpace}"
        helpText="${helpText:$availableSpace}"


        #get last space in toPrint

        if [ "$helpText" != "" ]; then

            lastPart="${toPrint##* }"

            local lastSpacePos=$(( ${#toPrint} - ${#lastPart} ))

            if [ "$lastPart" == "$toPrint" ] || [ "$lastSpacePos" -le "5" ]; then
                #accept cutting word if no space found
                lastSpacePos=$((availableSpace -2 ))
            fi

            if [ "$lastSpacePos" -gt 0 ]; then
                #if last space is not at the end of toPrint, put the text after last space back to helpText
                helpText="${toPrint:$lastSpacePos}$helpText"

                #remove the text after last space from toPrint
                toPrint="${toPrint:0:$lastSpacePos}"
            fi
        fi

        #print string
        printf "%s\n" "$toPrint"
        col=0

        if [ -z "$helpText" ]; then
            break
        fi
        helpText="  $helpText"
    done




    

}

old(){
    o.Get "$item.cmd"; local cmd="$_r"
    o.Get "$item.helpArgs"; local helpArgs="$_r"
    o.Get "$item.helpText"; local helpText="$_r"


    local boldCmd="\033[1m$cmd\033[0m"
    local italicHelpArgs="\033[3m$helpArgs\033[0m"

    local header="$boldCmd $italicHelpArgs"
    local headerNoFormat="$cmd $helpArgs"

    local totalHeaderSize=$(( ${#headerNoFormat} + 1 ))
    local identText
    printf -v identText "%*s" "$((identSize + 2))" ""

    if [ $totalHeaderSize -lt $identSize ]; then
        local sizeWithTextModifiers=$(( identSize  + ${#header} - ${#headerNoFormat} ))
        printf -v helpText "  %-${sizeWithTextModifiers}s %s" "$header" "$helpText"
    else
        printf "  $header\n"
        helpText="$identText $helpText"
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

    local line
    for line in "${linesArr[@]}"; do
        local tmpTerminalWidth=$terminalWidth
        if [[ "$line" == "  $header"* ]]; then
            #increase $terminal width to comport text style chars(\033[1m, \033[0m, etc) in the header
            tmpTerminalWidth=$((terminalWidth + ${#header} - ${#headerNoFormat} ))
        fi
        
        while true; do
            #break only on space or end of line, to avoid cutting words
            local cutPosition=$tmpTerminalWidth
            while true; do
                local charAtCutPos="${line:$((cutPosition - 1)):1}"
                if [ "$charAtCutPos" == " " ] || [ "$charAtCutPos" == "" ]; then
                    break;
                fi
                cutPosition=$((cutPosition - 1))
            done

            if [ $cutPosition -le $(( identSize + 10)) ]; then
                cutPosition=$terminalWidth
            fi

            if [ $cutPosition -gt $terminalWidth ]; then
                cutPosition=$terminalWidth
            fi

            local toPrint="${line:0:$cutPosition}"
            line="${line:$cutPosition}"

            #trim start
            line="${line#"${line%%[![:space:]]*}"}"

            printf "$toPrint\n"
            
            if [ -z "$line" ]; then
                break
            fi

            line="$identText   $line"
        done
    done

    if [ "$addEmptyLines" == "true" ]; then echo "";  fi
}

