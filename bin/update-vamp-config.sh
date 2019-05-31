#!/usr/bin/env bash
set -e

while getopts p:o:e: option
do
	case "${option}"
	in
	  p) BASE_PATH=${OPTARG};;
		o) ORG=${OPTARG};;
		e) ENV=${OPTARG};;
	esac
done

ENVSUBST_SHELL_FORMAT=\$VAMP_FORKLIFT_MYSQL_USER,\$VAMP_FORKLIFT_MYSQL_PASSWORD,\$VAMP_FORKLIFT_MYSQL_HOST,\$VAMP_FORKLIFT_SECURITY_LOOKUP_HASH_SALT,\$VAMP_FORKLIFT_SECURITY_PASSWORD_HASH_SALT

cd $BASE_PATH

cp forklift/config.yaml ~/.forklift

echo "Creating Vamp config for $ORG $ENV"
mkdir -p tmp
envsubst ${ENVSUBST_SHELL_FORMAT} < organization.yaml > tmp/organization.yaml
forklift create organization $ORG --file tmp/organization.yaml
#forklift create user org-admin --role admin --organization org
envsubst ${ENVSUBST_SHELL_FORMAT} < environment.yaml > tmp/environment.yaml
forklift create environment $ENV --organization $ORG --file tmp/environment.yaml

for workflow in $(ls workflows)
do
  echo "Adding $workflow workflow"
  forklift add artifact $workflow --organization $ORG --environment $ENV --file workflows/$workflow/breed.yaml
  forklift add artifact $workflow --organization $ORG --environment $ENV --file workflows/$workflow/workflow.yaml
done