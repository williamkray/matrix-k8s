#!/usr/bin/env bash

# this script will generate kustomize overlays for your stacks, and substitute placeholder values of various secrets in
# config files with your actual secrets as set in your variables.env file.

source variables.env

# copy base files into place as an overlay
for "domain" in $homeservers ; do 
  domain_var="${domain//\./}"
  mkdir -p apps/synapse/overlays/"${domain}"
  cp -r apps/synapse/base/{configs,secrets} apps/synapse/overlays/"${domain}"/
  # space separated list of variable ids to substitute
  var_id="prefix namespace organization"
  for id in $var_id; do
    # creative variable evaluation magic
    this_var=$(eval echo -n \$"${domain_var}_${id}")
    # this sed command should replace all instances of the vars in kustomization.yaml and config/secret directories
    sed -i "s/<REPLACE_WITH_${id^^}>/${this_var}/g" \
      apps/synapse/overlays/${domain}/kustomization.yaml \
      apps/synapse/overlays/${domain}/configs/*/*.yaml \
      apps/synapse/overlays/${domain}/secrets/*/*.yaml
  done
done
