#!/usr/bin/env bash
set -e

while getopts p:o:e:f: option
do
	case "${option}"
	in
	  p) BASE_PATH=${OPTARG};;
		o) ORG=${OPTARG};;
		e) ENV=${OPTARG};;
		f) FLAG_FILE=${OPTARG};;
	esac
done

diff=$(git diff @^ @ -- $BASE_PATH/config)
if [ -z "$diff" ]
then
  echo "Vamp config is unchanged"
  exit 0
fi

# set envsubst variable list
export ENVSUBST_SHELL_FORMAT=\$VAMP_FORKLIFT_MYSQL_USER,\$VAMP_FORKLIFT_MYSQL_PASSWORD,\
\$VAMP_FORKLIFT_MYSQL_HOST,\$VAMP_FORKLIFT_SECURITY_LOOKUP_HASH_SALT,\$VAMP_FORKLIFT_SECURITY_PASSWORD_HASH_SALT

mkdir -p ~/.forklift
cp ${BASE_PATH}/common/forklift/config.yaml ~/.forklift/

cd $BASE_PATH/config

mkdir -p tmp
rm -rf tmp/*

echo "Creating Vamp config for $ORG $ENV"
if [ "$(forklift list organizations | grep $ORG)" == "" ]
then
  echo "Creating $ORG"
	envsubst ${ENVSUBST_SHELL_FORMAT} < organization.yaml > tmp/organization.yaml
	forklift create organization $ORG --file tmp/organization.yaml
else
  echo "Updating $ORG"
	envsubst ${ENVSUBST_SHELL_FORMAT} < organization.yaml > tmp/organization.yaml
	forklift update organization $ORG --file tmp/organization.yaml
fi
if [ "$(forklift list environments --organization $ORG | grep $ENV)" == "" ]
then
  echo "Creating $ENV"
  envsubst ${ENVSUBST_SHELL_FORMAT} < environment.yaml > tmp/environment.yaml
  forklift create environment $ENV --organization $ORG --file tmp/environment.yaml
else
  echo "Updating $ENV"
  envsubst ${ENVSUBST_SHELL_FORMAT} < environment.yaml > tmp/environment.yaml
  forklift update environment $ENV --organization $ORG --file tmp/environment.yaml
fi

for workflow in $(ls workflows)
do
  echo "Adding $workflow workflow"
  forklift add artifact $workflow --organization $ORG --environment $ENV --file workflows/$workflow/breed.yaml
  forklift add artifact $workflow --organization $ORG --environment $ENV --file workflows/$workflow/workflow.yaml
done

for gateway_path in $(ls gateways)
do
  gateway=$(echo "${gateway_path}" | cut -d'.' -f1)
  echo "Adding $gateway gateway"
  forklift add artifact $gateway --organization $ORG --environment $ENV --file gateways/$gateway_path
done

echo "true" > $FLAG_FILE

#forklift create user org-admin --role admin --organization org
