#!/bin/bash
# To make this file excutable in bash: `chmod u+x YourScriptFileName.sh`
set -e # Instructs the script to terminate as soon as any command it executes fails, i.e., returns a non-zero exit status. 

# Make the directory of the file current directory
cd "$(dirname -- "`readlink -f -- "$0"`")"
echo -e '\n----' `basename -- $(pwd)`/`basename -- "$0"`

# Make the directory of the file current
cd "$( dirname -- "$( readlink -f -- "$0"; )"; )"
SECONDS=0  # Start the timer

set -x # Print commands and their arguments as they are executed.

./10_PROVIDER_setup_role_and_warehouse.sh
./20_PROVIDER_create_image_repository.sh
./30_PROVIDER_create_docker_image.sh

./40_LOCAL_create_app_services.sh
./42_LOCAL_smoke_test_app_services.sh


set +x # Disabling Command Tracing
echo " == DONE in $((SECONDS)) seconds."
