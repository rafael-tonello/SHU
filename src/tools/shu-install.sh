#!/bin/bash
useSudo=false
binDir="$HOME/.local/bin"
if [ ! -d "$binDir" ]; then
    binDir="~/.local/bin"
    if  [ ! -d "$binDir" ]; then
        useSudo=true

        binDir="/usr/local/bin"
        if [ ! -d "$binDir" ]; then
            binDir="/usr/bin"
        fi
    fi
fi

# A convenience script to install Shu CLI in your system.
#create temporary directory
rm -rf /tmp/shu-install
mkdir -p /tmp/shu-install
cd /tmp/shu-install
wget https://github.com/rafael-tonello/SHU/archive/refs/heads/main.zip 
unzip main.zip
cd SHU-main

rm -rf ~/.local/shu
mkdir -p ~/.local/shu
cp -r src/* ~/.local/shu
chown -R $(whoami):$(whoami) ~/.shu

# make the shu command executable
chmod +x ~/.local/shu/shu-cli.sh
#create a symlink to the shu command (shu main file is ~/.local/shu/shu.sh)
if [ "$useSudo" = true ]; then
    sudo rm -f $binDir/shu
    sudo ln -sf ~/.local/shu/shu-cli.sh $binDir/shu
else
    rm -f $binDir/shu
    ln -sf ~/.local/shu/shu-cli.sh $binDir/shu
fi


# remove temporary directory
cd ~
rm -rf /tmp/shu-install
echo "Shu CLI installed successfully!"
echo "You can now use the 'shu' command in your terminal. Try 'shu --help' to get started."

#run this script with:
# curl -sSL https://raw.githubusercontent.com/rafael-tonello/SHU/main/src/tools/shu-install.sh | bash
#shu installBashCompletion
