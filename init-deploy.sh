#!/usr/bin/env bash

# this script will generate kustomize overlays for your stacks, and substitute placeholder values of various secrets in
# config files with your actual secrets as set in your variables.env file.

source variables.env

# copy base files into place as an overlay
for domain in $homeservers ; do 
  domain_var="${domain//\./}"
  echo "copying template files into place for ${domain}"
  mkdir -p apps/synapse/overlays/"${domain}"
  cp -r apps/synapse/base/{kustomization.yaml,configs,secrets} apps/synapse/overlays/"${domain}"/
  # space separated list of variable ids to substitute
  var_id="prefix namespace organization synapse_db_name synapse_db_user synapse_db_password"
  for id in $var_id; do
    # creative variable evaluation magic
    this_var=$(eval echo -n \$"${domain_var}_${id}")
    if [[ -n "$this_var" ]]; then
      echo "replacing instances of ${domain_var}_${id}"
      # this sed command should replace all instances of the vars in kustomization.yaml and config/secret directories
      sed -i "s/<REPLACE_WITH_${id^^}>/${this_var}/g" \
        apps/synapse/overlays/${domain}/kustomization.yaml \
        apps/synapse/overlays/${domain}/configs/*/*.yaml \
        apps/synapse/overlays/${domain}/secrets/*/*.yaml
    else
      echo "${domain_var}_${id} variable is unset!" 
      echo "skipping this substitution. please manually update your files,"
      echo "or update your variables.env file and rerun this script."
    fi
  done
done
