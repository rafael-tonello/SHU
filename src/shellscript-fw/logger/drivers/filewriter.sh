logger.fileDriver.New(){
    local fileName="$1"; local maxSizeBytes="$2"
    local allowedSeverities="${3:-$ALL}"

    o.New "logger.fileDriver"; local driver="$_r"
    o.Set "$driver" "fileName" "$fileName"
    o.Set "$driver" "maxSizeBytes" "$maxSizeBytes"
    o.Set "$driver" "allowedSeverities" "$allowedSeverities"
    _r="$driver"
}

logger.fileDriver.Log(){ local logObject="$1"; local severity="$2"; local name="$3"; shift 3
    local fileName=$(o.Get "$logObject" "fileName")
    local maxSizeBytes=$(o.Get "$logObject" "maxSizeBytes")
    local allowedSeverities=$(o.Get "$logObject" "allowedSeverities")

    #check if the severity is allowed
    if [[ ! "$allowedSeverities" =~ "$severity" ]]; then
        return 0
    fi

    #check if the file exists and is larger than maxSizeBytes
    if [[ -f "$fileName" && $(stat -c%s "$fileName") -gt $maxSizeBytes ]]; then
        #compact the file
        logger.fileDriver.Compact "$fileName"
    fi

    #write the log message to the file
    #get date in the format YYYY-MM-DD HH:MM:SS.ffffff
    local dateFormated=$(date +"%Y-%m-%d %H:%M:%S.%6N")
    echo "[$dateFormated] [$severity] [$name] $@" >> "$fileName"
}

logger.fileDriver.Compact(){ local fileName="$1"
    #compact the file
    #get the first 100 lines of the file
    mv "$fileName" "$fileName.tmp"
    (
        #check for 7z command (generate a 7z file)
        if command -v 7z > /dev/null; then
            7z a "$fileName.7z" "$fileName.tmp"
            rm "$fileName.tmp"
        #check for zlib (generate a tar.gz file)
        elif command -v zlib > /dev/null; then
            tar -czf "$fileName.tar.gz" "$fileName.tmp"
            #remove the original file
            rm "$fileName.tmp"
        #check fo zip (generate a zip file)
        elif command -v zip > /dev/null; then
            zip "$fileName.zip" "$fileName.tmp"
            #remove the original file
            rm "$fileName.tmp"
        #check for gzip (generate a gz file)
        elif command -v gzip > /dev/null; then
            gzip "$fileName"
            #remove the original file
            rm "$fileName.tmp"
        else
            #if zlib is not available, just remove the file
            rm "$fileName.tmp"
        fi
    ) &
}