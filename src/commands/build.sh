#!/bin/bash

shu.Build(){ local _destinationName="${1:-}"
    if [ "$_destinationName" == "" ]; then
        #get project name from shu.yaml
        _destinationName="build/$SHU_PROJECT_NAME"
        mkdir -p "build"
    fi

    #add .sh to _destinationName (if not already present)
    if [[ "$_destinationName" != *.sh ]]; then
        _destinationName="$_destinationName.sh"
    fi

    if [ -f "$_destinationName" ]; then
        _error="File '$_destinationName' already exists. Please specify a different name or remove the existing file."
        return 1
    fi

    local mainScripts=()


    #compress current folder to a tar.gz file
    
    tar -czf "/tmp/shufiles.tar.gz" \
        --exclude=".git" \
        --exclude="*.test.*" \
        --exclude="*.log" \
        --exclude="*.tmp" \
        --exclude="temp" \
        --exclude="tmp" \
        --exclude="*.old" \
        --exclude="*.bak" . \
        --exclude="build" \
        --exclude="$_destinationName" \
    2>/tmp/shu-compression-error.log
    if [ $? -ne 0 ]; then
        _error="Error compressing current folder to tar.gz: $(cat /tmp/shu-compression-error.log)"
        rm /tmp/shu-compression-error.log
        return 1
    fi

    rm -rf /tmp/shfiles_parts
    mkdir -p /tmp/shfiles_parts

    #split file in parts of 50KiB

    split -b 50K "/tmp/shufiles.tar.gz" /tmp/shfiles_parts/shufiles_part_ --additional-suffix=.tar.gz 2> /tmp/shu-split-error.log
    if [ $? -ne 0 ]; then
        _error="Error splitting tar.gz file: $(cat /tmp/shu-split-error.log)"
        rm /tmp/shu-split-error.log
        return 1
    fi
    rm /tmp/shu-split-error.log
    rm /tmp/shufiles.tar.gz

    echo '#!/bin/bash\n' > "$_destinationName"
    #scroll parts of shufiles.tar.gz and check if they exist
    for targzfile in /tmp/shfiles_parts/shufiles_part_*.tar.gz; do
        #check if file exists
        if [ ! -f "$targzfile" ]; then
            _error="File '$targzfile' not found. Please check the split operation."
            rm /tmp/shu-compression-error.log
            return 1
        fi

        local blockBase64=$(base64 "$targzfile")
        echo 'echo "'$blockBase64'" | base64 -d >> /tmp/shufiles.tar.gz\n' >> "$_destinationName"
    done
    rm -rf /tmp/shfiles_parts

    echo '\n' >> "$_destinationName"
    echo 'tmpFolder=$(mktemp -d)\n' >> "$_destinationName"
    echo 'tar -xzf "/tmp/shufiles.tar.gz" -C "$tmpFolder" 2>/tmp/shu-extraction-error.log\n' >> "$_destinationName"
    echo 'if [ $? -ne 0 ]; then\n' >> "$_destinationName"
    echo '    echo "Error extracting $targzfile: $(cat /tmp/shu-extraction-error.log)"\n' >> "$_destinationName"
    echo '    rm /tmp/shu-extraction-error.log\n' >> "$_destinationName"
    echo '    exit 1\n' >> "$_destinationName"
    echo 'fi\n' >> "$_destinationName"
    echo 'rm /tmp/shufiles.tar.gz\n' >> "$_destinationName"
    echo 'rm /tmp/shu-extraction-error.log\n' >> "$_destinationName"

    local binCount=0
    shu.yaml.getArray "shu.yaml" ".main[]"; local mainScripts=("$_r")
    for main in "${shu_main_scripts[@]}"; do
        binCount=$((binCount + 1))
        echo "$tmpFolder/$main \"$@\"" >> "$_destinationName"
    done

    if [ $binCount -eq 0 ]; then
        shu_runner+='echo "No main scripts. Content of $tmpFolder:"\n'
        shu_runner+='ls -l "$tmpFolder"\n'
    fi

    chmod +x "$_destinationName"
}

#help is the SHU-cli command
shu.Build.Help(){
    echo "build                    - Build a shellscript project. Compile the project in a single .sh file. This command is focused on shellscript projects, and you can override it through 'shu pcommand' subcommands. See 'shu pcommand --help' for more information."
}

if [[ "$1" == "--help" || "$1" == "-h" || "$1" == "help"  ]]; then
    shu.Build.Help
    return 0
fi

shu.Build "$@"
return $?
