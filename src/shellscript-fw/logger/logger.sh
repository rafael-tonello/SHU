#!/bin/bash

#usage example 1
# logger.New --withFile "important.txt 1000000 $INFO_OR_HIGHER" --withConsole "DEBUG INFO" --withFile "debug.txt 1000000 $ALL"
# obj.call "logger.Info" "this is an info message"
# obj.call "logger.Debug" "this is a debug message"
# obj.call "logger.Warn" "this is a warning message"
# obj.call "logger.Error" "this is an error message"
# obj.call "logger.Fatal" "this is a fatal message"

#usage example 2 (nameLog)
# logger.New --withFile "important.txt 1000000 $INFO_OR_HIGHER" --withConsole "DEBUG INFO" --withFile "debug.txt 1000000 $ALL"
# logger.GetNamedLog "main"; nLog="$_r" #directly call class method
# obj.call "logger.GetNamedLog" "main"; nLog="$_r" #call class method using obj.call
# obj.call "nlogger.Debug" "this is a debug message"
# obj.call "nlogger.Info" "this is an info message"
# obj.call "nlogger.Warn" "this is a warning message"
# obj.call "nlogger.Error" "this is an error message"
# obj.call "nlogger.Fatal" "this is a fatal message"

#other ways to call optional methods
# logger.New "$(logger.withFile "important.txt 1000000 $INFO_OR_HIGHER")" "$(logger.withConsole "DEBUG INFO")" "$(logger.withFile "debug.txt 1000000 $ALL")"


thisscriptdir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$thisscriptdir/drivers/console.sh"
source "$thisscriptdir/drivers/filewriter.sh"


#TODO: as this library is part of shu, and misc is (probabily) already loaded, just check if misc is rally loaded

#ILoggerDriver{

    #args is passed, for example, for a call like logger.New "--drv ,myDrv,arg1,arg2,arg3", as arg1, arg2 and arg3
    ILoggerDriver.New(){ :; }

    ILoggerDriver.Log(){ local loggerInstance="$1"; local severity="$2"; local name="$3"; shift 3; message="$@"
        :; 
    } #this is the method that will be called to log messages
#}

#logger.New "--drv <cs><driverName><cs><arg1><cs><arg2>...", "--drv...", where
# <cs> is the character used to separate the driver name and its arguments. You can choose any charactr
# <driverName> is the name of the driver class (e.g. logger.consoleDriver, logger.fileDriver)
# <arg1>, <arg2>, ... are the arguments to be passed to the driver function <driverName>.New
logger.New(){
    o.New "log"; local logObject="$_r"
    logger.parseDrivers "$logObject" "$@"
    _r="$logObject"
}

TRACE="TRACE"
DEBUG="DEBUG"
INFO="INFO"
WARN="WARNING"
ERROR="ERROR"
FATAL="FATAL"
ALL="$TRACE $DEBUG $INFO $WARN $ERROR $FATAL"
DEBUG_OR_HIGHER="$DEBUG $INFO $WARN $ERROR $FATAL"
INFO_OR_HIGHER="$INFO $WARN $ERROR $FATAL"
WARN_OR_HIGHER="$WARN $ERROR $FATAL"
ERROR_OR_HIGHER="$ERROR $FATAL"

 
logger.WithFile(){ local fileName="$1"; local maxSizeBytes="$2"; local allowedSeverities="${3:-$ALL}"
    echo "--drv |logger.fileDriver|$fileName|$maxSizeBytes|$allowedSeverities"
}

logger.WithConsole(){ local allowedSeverities="${1:-$ALL}"; local allowColors="${2:-true}"
    echo "--drv ,logger.consoleDriver,$allowedSeverities,$allowColors"
}

logger.parseDrivers(){
    local logObject="$1"
    local i=0
    local drivers=()
    while true; do
        local arg="${!i}"; ((i++))
        if [[ -z "$arg" ]]; then
            break
        fi

        #check if argument begins with "--drv-"
        if [[ "$arg" == "--drv "* ]]; then
            #remove "--drv-" from the argument
            #the character with index 7 is the arg separator
            local separator="${arg:6:1}"

            arg=${arg:7}

            
            #split arg by '$separator' to the 'drvArgs' array
            IFS="$separator" read -r -a drvArgs <<< "$arg"
            

            #separate funcName and arguments by ':'
            local drvName="${drvArgs[0]}"
            unset drvArgs[0] #remove the first element (the driver name)
            local argsStr="${drvArgs[*]}"

            local drvNewFunc="$drvName.New"

            if ! o.Implements "$drvName" "ILoggerDriver"; then
                _error="driver '$drvName' does not implement ILoggerDriver interface: $_error"
                return 1
            fi

            #check if the function exists
            if declare -f "$drvNewFunc" > /dev/null; then
                eval "$drvNewFunc $argsStr"
                drivers+=("$_r")
            else
                echo "Error: Driver '$arg.New' not found."
                return 1
            fi
        fi
    done

    o.Set "$logObject" "drivers" "${drivers[@]}"

    _r="$logObject"
}

logger.GetNamedLogger(){ local log="$1"; local name="$2"
    logger._namedlogger.New "$log" "$name"
}; logger.getNLog(){ logger.getNamedLog "$@"; }

logger.Log(){ local logObject="$1"; local severity="$2"; local name="$3"
    shift 3
    o.GetArray "$logObject.drivers" "$log"; local drivers="${_r[@]}"
    
    for driver in "${drivers[@]}"; do
        #call the driver with the log message
        eval "$driver.Log \"$logObject\" \"$severity\" \"$name\" \"$@\""
    done
}

logger.Trace(){ local $logObject="$1"; shift
    logger.log "$logObject" "$TRACE" "$@"
}

logger.Debug(){ local $logObject="$1"; shift
    logger.log "$logObject" "$DEBUG" "$@"
}

logger.Info(){ local $logObject="$1"; shift
    logger.log "$logObject" "$INFO" "$@"
}

logger.Warn(){ local $logObject="$1"; shift
    logger.log "$logObject" "$WARN" "$@"
}

logger.Error(){ local $logObject="$1"; shift
    logger.log "$logObject" "$ERROR" "$@"
}

logger.Fatal(){ local $logObject="$1"; shift
    logger.log "$logObject" "$FATAL" "$@"
}

#NamedLogger class {
    log._namedLogger.New(){
        local logObject="$1"; local name="$2"
        o.New "log._namedLog"; local nLog="$_r"

        #set the log object and name
        o.Set "$nLog" "logObject" "$logObject"
        o.Set "$nLog" "name" "$name"
    }

    log._namedLogger.Log(){ local nLog="$1"; local severity="$2"
        o.Get "$nLog" "logObject"; local logObject="$_r"
        o.Get "$nLog" "name"; local name="$_r"
        o.Call "$logObject.Log" "$logObject" "$severity" "$name" 
    }

    log._namedLogger.Trace(){ local nLog="$1"; shift
        log._namedLogger.Log "$nLog" "$TRACE" "$@"
    }

    log._namedLogger.Debug(){ local nLog="$1"; shift
        log._namedLogger.Log "$nLog" "$DEBUG" "$@"
    }

    log._namedLogger.Info(){ local nLog="$1"; shift
        log._namedLogger.Log "$nLog" "$INFO" "$@"
    }

    log._namedLogger.Warn(){ local nLog="$1"; shift
        log._namedLogger.Log "$nLog" "$WARN" "$@"
    }

    log._namedLogger.Error(){ local nLog="$1"; shift
        log._namedLogger.Log "$nLog" "$ERROR" "$@"
    }

    log._namedLogger.Fatal(){ local nLog="$1"; shift
        log._namedLogger.Log "$nLog" "$FATAL" "$@"
    }
#}



