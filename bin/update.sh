#!/usr/bin/env bash

set -e

if [ -f ./updated ] || compgen -G "./configure-*" > /dev/null
then
  vamp_flag_file_path=$(pwd)

  for brand in $(ls brands)
  do
    for config in $(ls brands/$brand/*.yaml)
    do
      context=$(basename $config | cut -d'.' -f1)
      environment=$(echo $context | cut -d'-' -f2)

      echo "Updating $brand $environment"
      
      cp -r common brands/$brand/$environment/infrastructure/vamp
      
      vamp-kmt \
        --service-defs kmt-example-service-catalog \
        --application kmt-example-applications/$brand/$environment.yaml \
        --environment $config \
        --release-plans release-plans \
        --output brands/$brand/$environment

      bin/update-vamp-config.sh \
        -p brands/$brand/$environment/infrastructure/vamp \
        -o $brand \
        -e $environment \
        -f $vamp_flag_file_path

      updated_flag=true
      python3 bin/copy_services.py \
        --config $config \
        --src-path kmt-example-service-catalog \
        --dst-path brands/$brand/$environment/services || updated_flag=false

      if [ "$updated_flag" = true ]
      then
  			pushd brands/$brand/$environment
  			for service in $(ls services/)
  			do
      		if [ -f services/$service/kustomization.yaml ] && \
      		   [ -z "$(cat kustomization.yaml | grep services/$service)" ]
      		then
        		kustomize edit add base services/$service
      		fi
  			done
  			popd

        kubectl config use-context $context
        kustomize build brands/$brand/$environment | kubectl apply -f -
      fi
    done
  done
  [ ! -f ./updated ] || rm ./updated
  [ ! -f ./configure-vamp ] || rm ./configure-vamp
else
  echo "Nothing to update"
fi