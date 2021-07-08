#!/usr/bin/env bash

set -e

# this script creates namespaces used in your variables file to ensure you can actually deploy your resources as created
# by the generate-overlays.sh script
# if you leave all namespaces in your variables file set to "default" you can skip running this as it won't do anything.

if [[ -n "$1" ]] && [[ -f "$1" ]]; then
  vars_file="$1"
else
  echo "no argument received"
  vars_file="./variables.env"
fi

# be lazy and create namespaces without manifests
namespaces=""
for ns in $(grep ^[\sa-zA-Z_]*_namespace $vars_file | awk -F '=' '{print $2}' | tr -d \"\' | uniq); do
  if [[ $(kubectl get namespace $ns 2>/dev/null) ]]; then
    echo "namespace $ns already exists, skipping"
  else
    kubectl create namespace $ns
  fi
done
