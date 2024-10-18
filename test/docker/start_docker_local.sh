#!/bin/bash
set -e # Instructs the script to terminate as soon as any command it executes fails, i.e., returns a non-zero exit status. 

# Make the directory of the file 'snowflake.yml' the current directory
this_dir="$( dirname -- "$( readlink -f -- "$0"; )"; )"
cd "$this_dir/../.."
pwd

docker build --rm --platform linux/amd64 -t infostrux_extractor_image:local .

echo "In your browser, on the same computer, open http://localhost:8080/ui"
docker volume create infostrux_extractor_output
docker run --rm --volume infostrux_extractor_output:/service/output --publish 8080:8080 --name infostrux_extractor infostrux_extractor_image:local &

# In your browser, on the same computer, open http://localhost:8080/ui
# git-bash on windows
# start chrome http://localhost:8080/ui
