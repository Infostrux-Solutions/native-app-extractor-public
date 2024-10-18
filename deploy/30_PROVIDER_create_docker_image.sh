#!/bin/bash
# To make this file excutable in bash: `chmod u+x YourScriptFileName.sh`
set -e # Instructs the script to terminate as soon as any command it executes fails, i.e., returns a non-zero exit status. 

# Make the directory of the file 'snowflake.yml' the current directory
this_dir="$( dirname -- "$( readlink -f -- "$0"; )"; )"
proj_dir="$( dirname -- "$( readlink -f -- "$this_dir"; )"; )"
cd "$proj_dir"

SECONDS=0  # Start the timer

APP_PREFIX=infostrux_extractor
APP_DATABASE="${APP_PREFIX}"
APP_ROLE="${APP_PREFIX}_role"
IMAGE="${APP_PREFIX}_image:latest"

echo -e "\n==  1. Build a Docker image"
#    Note that you must specify the current working directory (.) in the command
docker build --rm --platform linux/amd64 -t  $IMAGE .

echo -e "\n==  2. Identify the URL of the image repository created in the previous section"
REPO_URL=$(snow spcs image-repository url ${APP_DATABASE}.image_repository_schema.image_repository_stage --role ${APP_ROLE})
echo "  - REPO_URL:" $REPO_URL

echo -e "\n==  3. Create tag for the image that includes the image URL"
#    docker tag <image_name> <image_url>/<image_name>
docker tag $IMAGE $REPO_URL/$IMAGE

echo -e "\n==  4. Authenticate with the Snowflake registry"
snow spcs image-registry login

echo -e "\n==  5. Upload the Docker image to the image repository"
docker push $REPO_URL/$IMAGE

echo -e "\n==  6. Confirm the image was uploaded successfully"
snow spcs image-repository list-images ${APP_DATABASE}.image_repository_schema.image_repository_stage --role ${APP_ROLE}


echo " == DONE Docker image '$IMAGE' build & push: $((SECONDS)) seconds."
