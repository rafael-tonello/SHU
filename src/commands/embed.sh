#TODO: copy all content of (install) <shu project>/src in the <project_root>/shu/bin folder (note that folder is not '.shu', but 'shu')
#TODO: creates a bash file named 'shu' (without extension) in the <project_root> taht redirects to <project_dir>/shu/bin/shu-cli.sh (to allow user to run ./shu command in root proejct folder)

shu.embed.main(){
    :;
}

shu.depMain(){
    :;
}

shu.pdeps.Help(){
    echo "embed [options]          - Embed shu inside you project. It make you able to use shu without installing it in the system (using ./shu, in the project root folder, instead 'shu' system command). Shu will be downloaded from its repository and installed in '<project_root>/shu/bin and a script named 'shu' (without extension) will be created in the project root folder that redirects to '<project_root>/shu/bin/shu-cli.sh'."
    echo "  options:"
    echo "    --local-copy           - Will copy the local shu installation instead of downloading it from the repository. "  
    echo "    @<checkout>            - Will run git checkout <checkout> before embedding shu. This is useful to embed a specific version of shu. If not provided, the last version will be used. This cannot be used with --local-copy option."
    ecgi "    --dest <path>          - Copy shu to the directory <project_root>/<path> instead of the default '<project_root>/shu'."
}


shu.depMain "$@"
return $?
