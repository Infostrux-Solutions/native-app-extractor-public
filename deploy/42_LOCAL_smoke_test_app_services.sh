#!/bin/bash
# To make this file excutable in bash: `chmod u+x YourScriptFileName.sh`
set -e # Instructs the script to terminate as soon as any command it executes fails, i.e., returns a non-zero exit status. 

# Make the directory of the file 'snowflake.yml' the current directory
this_dir="$( dirname -- "$( readlink -f -- "$0"; )"; )"
proj_dir="$( dirname -- "$( readlink -f -- "$this_dir"; )"; )"
cd "$proj_dir"

echo "== Smoke test local service"
snow sql \
    -f deploy/00_set_vars_for_cli.sql \
    -f deploy/40_LOCAL_set_vars.sql \
    -f deploy/42_LOCAL_smoke_test_create_integration.sql \
    -f deploy/42_LOCAL_smoke_test_run.sql
