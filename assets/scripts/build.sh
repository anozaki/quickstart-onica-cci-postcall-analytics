#!/bin/bash

set -e

# Location of the portal
DIST_DIR="dist"
PORTAL="assets/portal"
BACKEND="functions/source"
PROJECT_DIR="../../"


COMMAND=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
  -s | --stage)
    STAGE="$2"
    shift # past argument
    shift # past value
    ;;
  -r | --region)
    REGION="$2"
    shift # past argument
    shift # past value
    ;;
  *) # unknown option
    COMMAND+=("$1") # save it in an array for later
    shift           # past argument
    ;;
  esac
done
set -- "${COMMAND[@]}" # restore positional parameters

echo "STAGE  = ${STAGE}"
echo "REGION = ${REGION}"


export DEPLOY_ENVIRONMENT=$STAGE
export REGION=$REGION
export CUSTOM_VOCABULARY_NAME="custom-vocabulary"

function build() {
  echo "Cleaning in progress"
  if [ -d "$DIST_DIR" ]; then
    echo "Deleting $DIST_DIR"
    rm -rf "$DIST_DIR"
  fi

  echo "Building in progress stage: $STAGE region: $REGION"


  mkdir -p $DIST_DIR/functions/packages
  mkdir -p $DIST_DIR/functions/sources
  mkdir -p $DIST_DIR/templates
  mkdir -p $DIST_DIR/assets/training/motivation
  mkdir -p $DIST_DIR/assets/training/resolution
  mkdir -p $DIST_DIR/assets/transcribe
  mkdir -p $DIST_DIR/assets/portal  


  # Execute the build process for the serverless project
  cd "$BACKEND" || exit
  eval "npm install"
  eval "npx serverless package --region $REGION --stage $STAGE"

  # Copy the generated lambda zip
  cp ".serverless/aws-icc.zip" "$PROJECT_DIR$DIST_DIR/functions/packages/aws-icc.zip"
  cp ".serverless/custom-resources.zip" "$PROJECT_DIR$DIST_DIR/functions/packages/custom-resources.zip"

  cd "$PROJECT_DIR"

  # Copy custom vocabulary
  cp "./assets/transcribe/"* "$DIST_DIR/assets/transcribe"

  # Copy training data
  cp "./assets/training/motivation/"* "$DIST_DIR/assets/training/motivation"
  cp "./assets/training/resolution/"* "$DIST_DIR/assets/training/resolution"


  # Modifies the cloudformation template generated by the Serverless Framework
  cp "$BACKEND/.serverless/cloudformation-template-update-stack.json" "templates/aws-icc.template"
  eval "python assets/scripts/transform.py --template templates/aws-icc.template --save templates/aws-icc.template --zip functions/packages/aws-icc.zip" --custom "functions/packages/custom-resources.zip"

  # Copies all the templates to the .dist directory
  cp -rf "./templates/"* "$DIST_DIR/templates"

  # # # Build the frontend portal
  cd "./$PORTAL" || exit
  eval "npm install"
  eval "npm run build:production"
  cd "$PROJECT_DIR"

  # Copy all the files from the frontend build into the .dist directory
  cp -rf "./$PORTAL/build/"* "$DIST_DIR/assets/portal"
  }

echo "Running Command: ${COMMAND[0]}"

case $COMMAND in
build) build $STAGE $REGION ;;
*) ;;
esac