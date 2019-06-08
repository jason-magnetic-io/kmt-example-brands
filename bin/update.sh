#!/usr/bin/env bash

set -e

if [ -e updated ]
then
  vamp_flag_file=$(pwd)/vamp-updated

  for brand in $(ls brands)
  do
    for config in $(ls brands/$brand/*.yaml)
    do
      context=$(basename $config | cut -d'.' -f1)
      environment=$(echo $context | cut -d'-' -f2)

      echo "Updating $brand $environment"
      
      cp -r common brands/$brand/$environment/infrastructure/vamp
      
      bin/update-vamp-config.sh \
        -p brands/$brand/$environment/infrastructure/vamp \
        -o $brand \
        -e $environment \
        -f $vamp_flag_file

      vamp-kmt \
        --service-defs kmt-example-service-catalog \
        --application kmt-example-applications/$brand/$environment.yaml \
        --environment $config \
        --release-plans release-plans \
        --output brands/$brand/$environment

      updated_flag=true
      python3 bin/copy_services.py \
        --config $config \
        --src-path kmt-example-service-catalog \
        --dst-path brands/$brand/$environment/services || updated_flag=false

      if [ "$updated_flag" = true ]
      then
        kubectl config use-context $context
        kustomize build brands/$brand/$environment | kubectl apply -f -
      fi
    done
  done
  rm updated
else
  echo "Nothing to update"
fi