#!/bin/bash

#runs shu-cli tests with hot reload (when you change shu-cli.sh or shu-cli.test.sh it will run the tests again)
#you can specify 'docker' or 'podman' as the first argument to use that container engine

#docker=docker
docker=podman

#check if docker or podman was informed in the first argument
if [ "$1" == "docker" ] || [ "$1" == "podman" ]; then
    docker=$1
    shift
fi

cd ..
$docker build -t shu-tests .

#run command shhotreload.sh "/opt/src/shu-cli.test.sh" "clear" "" "/opt/shu-cli.sh"
$docker run --rm -v.:/opt shu-tests \
    bash -c 'export TERM=xterm; cd /opt/tests; shhotreload.sh "/opt/tests/runtests.sh" "clear" "" $(find *.sh ..)'
