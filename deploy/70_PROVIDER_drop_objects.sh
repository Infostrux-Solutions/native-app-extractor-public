#!/bin/bash
# To make this file excutable in bash: `chmod u+x YourScriptFileName.sh`
set -e # Instructs the script to terminate as soon as any command it executes fails, i.e., returns a non-zero exit status. 

# Make the directory of the file 'snowflake.yml' the current directory
this_dir="$( dirname -- "$( readlink -f -- "$0"; )"; )"
proj_dir="$( dirname -- "$( readlink -f -- "$this_dir"; )"; )"
cd "$proj_dir"

snow sql \
    -f deploy/00_set_vars_for_cli.sql  \
    -f deploy/70_PROVIDER_drop_objects.sql \
    --role ACCOUNTADMIN
