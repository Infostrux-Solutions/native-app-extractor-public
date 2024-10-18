#!/bin/bash
set -e # Instructs the script to terminate as soon as any command it executes fails, i.e., returns a non-zero exit status. 

# Make the directory of the file 'snowflake.yml' the current directory
this_dir="$( dirname -- "$( readlink -f -- "$0"; )"; )"
cd "$this_dir/../.."
pwd

docker stop infostrux_extractor