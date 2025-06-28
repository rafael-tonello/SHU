logger.consoleDriver.New(){
    local allowedSeverities="${1:-$ALL}"
    local allowColors="${2:-true}"

    o.New "logger.consoleDriver"; local driver="$_r"
    o.Set "$driver" "allowColors" "$allowColors"
    o.Set "$driver" "allowedSeverities" "$allowedSeverities"
    _r="$driver"
}

logger.consoleDriver.Log(){ local logObject="$1"; local severity="$2"; local name="$3"; shift 3
    local allowColors=$(o.Get "$logObject" "allowColors")
    local allowedSeverities=$(o.Get "$logObject" "allowedSeverities")

    #check if the severity is allowed
    if [[ ! "$allowedSeverities" =~ "$severity" ]]; then
        return 0
    fi

    #get date in the format YYYY-MM-DD HH:MM:SS.ffffff
    local dateFormated=$(date +"%Y-%m-%d %H:%M:%S.%6N")
    #print the log message to the console
    if [ "$allowColors" = "true" ]; then
        local colorPrefix=""
        local colorSuffix=""
        #set the color prefix and suffix
        case "$severity" in
            "$DEBUG") colorPrefix="\e[1;34m";;
            "$INFO") colorPrefix="\e[1;32m";;
            "$WARN") colorPrefix="\e[1;33m";;
            "$ERROR") colorPrefix="\e[1;31m";;
            "$FATAL") colorPrefix="\e[1;35m";;
        esac
        colorSuffix="\e[0m"

        echo -e "$colorPrefix[$dateFormated] [$severity] [$name] $@$colorSuffix"
    else
        echo "[$dateFormated] [$severity] [$name] $@"
    fi
}