#!/usr/bin/env bash

set -e

for brand in $(ls brands)
do
	echo $brand
	for config in $(ls brands/$brand/*.yaml)
	do
		context=$(basename $config | cut -d'.' -f1)
		environment=$(echo $context | cut -d'-' -f2)
		echo "Updating $brand $environment"
		python bin/copy_services.py \
		  --config $config \
		  --src-path kmt-example-service-catalog \
		  --dst-path brands/$brand/production/services
    kubectl config use-context $context
		kustomize build brands/$brand/$environment | kubectl apply -f -
	done
done
