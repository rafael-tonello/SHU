#!/bin/bash

#read -p "Informe a existing shu folder for testes: " shu_folder
firstLine=$(head -n 1 /tmp/tmpshulaunchtaskvalue 2>/dev/null)
secondLine=$(head -n 2 /tmp/tmpshulaunchtaskvalue | tail -n 1)

shu_folder=$(zenity --file-selection --directory --title="Select a shu folder for tests (cancel will use a new one)" --filename="$firstLine" 2>/dev/null)
if [[ $? -ne 0 ]]; then
    exit 1
fi


if [[ -z "$shu_folder" ]]; then
    rm -rf /tmp/tmpshufolder
    mkdir -p /tmp/tmpshufolder
    shu_folder="/tmp/tmpshufolder"
elif [[ ! -d "$shu_folder" ]]; then
    echo "The folder $shu_folder does not exist."
    exit 1
fi

echo "$shu_folder" > /tmp/tmpshulaunchtaskvalue

#read -p 'shu command to start: ' cmd;

cmd=$(zenity --entry --title="Command to start shu" --text="Enter the command to start shu:" --entry-text="$secondLine" 2>/dev/null)
if [[ $? -ne 0 ]]; then
    exit 1
fi

echo "$cmd" >> /tmp/tmpshulaunchtaskvalue