#!/bin/bash

#checkCommand unzip
fail=false
printError(){
    echo -e "\033[31mError: $1\033[0m" 1>&2
}

printWarning(){
    echo -e "\033[33mWarning: $1\033[0m" 1>&2
}
if ! command -v unzip &> /dev/null; then
    printError "unzip command not found. Please install it first."
    fail=true
fi

if $fail; then
    exit 1
fi


needLnWithSudo=false
binDir="$HOME/.local/bin"
if [ ! -d "$binDir" ]; then
    binDir="~/.local/bin"
    if  [ ! -d "$binDir" ]; then
        #yellow message
        printWarning "If shu fails to install, try running this command again with 'sudo' or root permissions."

        binDir="/usr/local/bin"
        if [ ! -d "$binDir" ]; then
            binDir="/usr/bin"
        fi
        needLnWithSudo=true
    fi
fi

# A convenience script to install Shu CLI in your system.
#create temporary directory
rm -rf /tmp/shu-install
mkdir -p /tmp/shu-install
cd /tmp/shu-install
#wget https://github.com/rafael-tonello/SHU/archive/refs/heads/main.zip 
curl -sSL https://github.com/rafael-tonello/SHU/archive/refs/heads/main.zip -o main.zip
unzip main.zip
if [ "$?" -ne 0 ]; then
    printError "Failed to copy Shu CLI files. Please check permissions or try running with sudo."
    exit 1
fi
cd SHU-main

rm -rf $HOME/.local/shu
mkdir -p $HOME/.local/shu
cp -r src/* $HOME/.local/shu
if [ "$?" -ne 0 ]; then
    printError "Failed to copy Shu CLI files. Please check permissions or try running with sudo."
    exit 1
fi


#chown -R $(whoami):$(whoami) ~/.shu
#if [ "$?" -ne 0 ]; then
#    printError "Failed to change ownership of ~/.shu directory. Please check permissions or try running with sudo."
#    exit 1
#fi

# make the shu command executable
chmod +x $HOME/.local/shu/shu-cli.sh
if [ "$?" -ne 0 ]; then

    printError "Failed to make shu-cli.sh executable. Please check permissions or try running with sudo."
    exit 1
fi


retcode=1
if $needLnWithSudo; then
    sudo rm -f $binDir/shu
    sudo ln -sf "$HOME/.local/shu/shu-cli.sh" "$binDir/shu"
    retcode=$?
else
    rm -f $binDir/shu
    ln -sf "$HOME/.local/shu/shu-cli.sh" "$binDir/shu"
    retcode=$?
fi

if [ "$retcode" -ne 0 ]; then
    printError "Failed to create symbolic link for shu command. Please check permissions or try running with sudo."
    exit 1
fi

# remove temporary directory
cd ~
rm -rf /tmp/shu-install
echo "Shu CLI installed successfully!"
echo "You can now use the 'shu' command in your terminal. Try 'shu --help' to get started."

#run this script with:
# curl -sSL https://raw.githubusercontent.com/rafael-tonello/SHU/main/src/tools/shu-install.sh | bash
#shu installBashCompletion