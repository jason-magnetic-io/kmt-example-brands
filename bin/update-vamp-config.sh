#!/usr/bin/env bash
set -e

while getopts p:o:e:f: option
do
	case "${option}"
	in
	  p) BASE_PATH=${OPTARG};;
		o) ORG=${OPTARG};;
		e) ENV=${OPTARG};;
		f) FLAG_FILE_PATH=${OPTARG};;
	esac
done

diff="$(git diff @^ -- $BASE_PATH/config)$(git status -s $BASE_PATH/config)"
if [ -z "$diff" ] && [ ! -f "${FLAG_FILE_PATH}/configure-vamp" ] \
  && [ ! -f "${FLAG_FILE_PATH}/configure-${ORG}-${ENV}" ]
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

created="false"
echo "Creating Vamp config for $ORG $ENV"
if [ "$(forklift list organizations | grep $ORG)" == "" ]
then
  echo "Creating $ORG"
  deploy_gateways="true"
	envsubst ${ENVSUBST_SHELL_FORMAT} < organization.yaml > tmp/organization.yaml
	forklift create organization $ORG --file tmp/organization.yaml
else
	diff="$(git diff @^ -- organization.yaml)$(git diff -- organization.yaml))"
  if [ ! -z "$diff" ] \
     || [ -f "${FLAG_FILE_PATH}/configure-vamp" ] \
     || [ -f "${FLAG_FILE_PATH}/configure-${ORG}-${ENV}" ]
  then
    echo "Updating $ORG"
    deploy_gateways="true"
	  envsubst ${ENVSUBST_SHELL_FORMAT} < organization.yaml > tmp/organization.yaml
	  forklift update organization $ORG --file tmp/organization.yaml
  fi
fi
if [ "$(forklift list environments --organization $ORG | grep $ENV)" == "" ]
then
  echo "Creating $ENV"
  deploy_gateways="true"
  envsubst ${ENVSUBST_SHELL_FORMAT} < environment.yaml > tmp/environment.yaml
  forklift create environment $ENV --organization $ORG --file tmp/environment.yaml
else
	diff="$(git diff @^ -- environment.yaml)$(git diff -- environment.yaml))"
  if [ ! -z "$diff" ] \
     || [ -f "${FLAG_FILE_PATH}/configure-vamp" ] \
     || [ -f "${FLAG_FILE_PATH}/configure-${ORG}-${ENV}" ]
  then
	  echo "Updating $ENV"
  	deploy_gateways="true"
  	envsubst ${ENVSUBST_SHELL_FORMAT} < environment.yaml > tmp/environment.yaml
  	forklift update environment $ENV --organization $ORG --file tmp/environment.yaml
  fi
fi

for workflow in $(ls workflows)
do
  echo "Adding $workflow workflow"
  forklift add artifact $workflow --organization $ORG --environment $ENV --file workflows/$workflow/breed.yaml
  forklift add artifact $workflow --organization $ORG --environment $ENV --file workflows/$workflow/workflow.yaml
done

# Fix this once VE-731 allows names with dashes
forklift add releasepolicy sava-product-basic --environment $ENV --organization $ORG --file policies/$ORG-basic-sava-product.json
forklift add releasepolicy sava-cart-basic --environment $ENV --organization $ORG --file policies/$ORG-basic-sava-cart.json

for gateway_path in $(ls gateways)
do
  gateway=$(echo "${gateway_path}" | cut -d'.' -f1)
  
  # prevent unnecessary updates
	diff="$(git diff @^ -- ${gateway_path})$(git diff -- ${gateway_path})$(git status -s ${gateway_path})"
  if [ -z "$diff" ] \
    && [ ! "$deploy_gateways" = "true" ]\
    && [ ! -f "${FLAG_FILE_PATH}/configure-vamp" ] \
    && [ ! -f "${FLAG_FILE_PATH}/configure-${ORG}-${ENV}" ]
  then
    echo "$gateway gateway is unchanged"
  else
    echo "Adding $gateway gateway"
    forklift add artifact $gateway --organization $ORG --environment $ENV --file gateways/$gateway_path
	fi
done

date > ${FLAG_FILE_PATH}/vamp-updated

#forklift create user org-admin --role admin --organization org
