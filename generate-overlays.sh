#!/usr/bin/env bash

set -e

# this script will generate kustomize overlays for your stacks, and substitute placeholder values of various secrets in
# config files with your actual secrets as set in your variables.env file.
# pass a file with variable values to source custom values.

if [[ -n "$1" ]] && [[ -f "$1" ]]; then
  vars_file="$1"
else
  echo "no argument received"
  vars_file="./variables.env"
fi
echo "sourcing variables from $vars_file"
source $vars_file

## SYNAPSE ##
# copy base files into place as an overlay
for domain in $homeservers ; do 
  domain_var="${domain//\./}"
  echo "copying template files into place for ${domain}"
  mkdir -p apps/synapse/overlays/"${domain}"
  cp -r apps/synapse/base/overlay_artifacts/* apps/synapse/overlays/"${domain}"/
  # this sed command tackles just the ingress files
  sed -i "s/<REPLACE_WITH_SYNAPSE_HOMESERVER>/${domain}/g" apps/synapse/overlays/${domain}/synapse-ingress.yaml
  sed -i "s/<REPLACE_WITH_SYNAPSE_HOMESERVER_STRIPPED>/${domain_var}/g" apps/synapse/overlays/${domain}/synapse-ingress.yaml
  # lets-encrypt options
  # set a value just so we don't get an annoying complaint message when it doesn't matter
  eval ${domain_var}_le_staging_val='-staging-'
  # i'm doing it this way because i'm too lazy to do it properly like i did for mmr below
  if [[ $(eval echo -n \$"${domain_var}_use_le") == true ]]; then
    if ! [[ $(eval echo -n \$"${domain_var}_le_staging") == false ]]; then
      eval ${domain_var}_le_staging_val='-staging-'
    else
      eval ${domain_var}_le_staging_val='-'
    fi
    echo -e "patches:\n  - patch01-acme-cert-issuer.yaml" >> apps/synapse/overlays/${domain}/kustomization.yaml
  fi

  # we need to process nginx as well for federation to work
  mkdir -p apps/nginx/overlays/"${domain}"
  cp -r apps/nginx/base/overlay_artifacts/* apps/nginx/overlays/"${domain}"

  # space separated list of variable ids to substitute
  var_id="prefix namespace organization domain le_staging_val acme_email synapse_db_name synapse_db_user
    synapse_db_password jitsi_domain nginx_image nginx_image_tag"
  for id in $var_id; do
    # creative variable evaluation magic
    this_var=$(eval echo -n \$"${domain_var}_${id}")
    if [[ -n "$this_var" ]]; then
      echo "replacing instances of <REPLACE_WITH_${id^^}> with ${this_var}"
      # this sed command should replace all instances of the vars in kustomization.yaml and config/secret directories
      sed -i "s#<REPLACE_WITH_${id^^}>#${this_var}#g" \
        apps/synapse/overlays/${domain}/*.yaml \
        apps/synapse/overlays/${domain}/configs/*/* \
        apps/synapse/overlays/${domain}/secrets/*/* \
        apps/nginx/overlays/${domain}/*.yaml \
        apps/nginx/overlays/${domain}/configs/*/* 
    else
      echo "${domain_var}_${id} variable is unset!" 
      echo "skipping this substitution. please manually update your files,"
      echo "or update your variables.env file and rerun this script."
    fi
  done
done

## MATRIX-MEDIA-REPO ##
if [[ "$mmr_multitenant" == true ]]; then
  tenant="multitenant"
  mmr_homeservers=${mmr_homeservers:=${homeservers}}
  ## generate kustomization.yaml and copy proper config files
  if [[ "$mmr_multitenant_local_storage" == true ]]; then
    storage_type="localstorage"
    overlay_dir="${tenant}_${storage_type}"
    kustom_bits="kustom00-common.yaml kustom01-generators-localstorage.yaml kustom02-resources-localstorage.yaml kustom03-patches-localstorage.yaml"
    # additional resources and patches to use
    patches="mmr-pvc.yaml patch01-use-local-storage.yaml"
  else
    storage_type="s3storage"
    overlay_dir="${tenant}_${storage_type}"
    kustom_bits="kustom00-common.yaml kustom01-generators-nolocalstorage.yaml kustom02-resources-nolocalstorage.yaml"
    patches=""
  fi

  echo "configuring overlay ${overlay_dir}..."
  rm -f apps/mmr/overlays/${overlay_dir}/kustomization.yaml
  mkdir -p apps/mmr/overlays/${overlay_dir}/ingresses
  for bit in $kustom_bits; do
    cat apps/mmr/base/overlay_artifacts/$bit >> apps/mmr/overlays/${overlay_dir}/kustomization.yaml
  done
  for patch in $patches; do
    cp apps/mmr/base/overlay_artifacts/$patch apps/mmr/overlays/${overlay_dir}/
  done
  cp -r apps/mmr/base/overlay_artifacts/{configs,secrets} apps/mmr/overlays/${overlay_dir}/
  # start with a fresh "homeservers" config
  echo 'homeservers:' > apps/mmr/overlays/${overlay_dir}/configs/mmr/03-homeservers.yaml
  for homeserver in $mmr_homeservers; do
    # generate ingress objects for each homeserver
    prefix=$(eval echo -n \$"${homeserver//\./}_prefix")
    namespace=$(eval echo -n \$"${homeserver//\./}_namespace")
    service_uri="http://${prefix}synapse.${namespace}.svc.cluster.local"
    echo "generating ingress resource for ${homeserver}"
    cp apps/mmr/base/overlay_artifacts/mmr-ingress.yaml \
      apps/mmr/overlays/${overlay_dir}/ingresses/mmr_${homeserver//\./}_ingress.yaml
    sed -i "s/<REPLACE_WITH_MMR_HOMESERVER>/${homeserver}/g" \
      apps/mmr/overlays/${overlay_dir}/ingresses/mmr_${homeserver//\./}_ingress.yaml
    # do some manual work to use the domain prefix here to match synapse ingress rule naming convention
    sed -i "s/<REPLACE_WITH_PREFIX>/${prefix}/g" \
      apps/mmr/overlays/${overlay_dir}/ingresses/mmr_${homeserver//\./}_ingress.yaml

    # generate a homeservers.yaml config that includes all homeservers
    echo -e "  - name: ${homeserver}\n    csApi: ${service_uri}:8008\n    adminApiKind: synapse\n" \
      >> apps/mmr/overlays/${overlay_dir}/configs/mmr/03-homeservers.yaml
  done
  # include ingress object manifests in kustomization
  echo "resources:" > apps/mmr/overlays/${overlay_dir}/ingresses/kustomization.yaml
  find apps/mmr/overlays/${overlay_dir}/ingresses/ -type f -name *_ingress.yaml -execdir echo "  - {}" >> \
    apps/mmr/overlays/${overlay_dir}/ingresses/kustomization.yaml \;
  # generate an admins config file
  echo "admins:" > apps/mmr/overlays/${overlay_dir}/configs/mmr/05-admins.yaml
  for user in $(eval echo -n \$"mmr_${tenant}_admins"); do
    echo "  - \"${user}"\" >> apps/mmr/overlays/${overlay_dir}/configs/mmr/05-admins.yaml
  done


  # swap out variables in secrets/configmaps
  var_id="namespace local_storage local_storage_size s3_bucket_name s3_access_key s3_secret_key s3_endpoint db_name \
    db_user db_password"
  for id in $var_id; do
    # creative variable evaluation magic
    this_var=$(eval echo -n \$"mmr_${tenant}_${id}")
    if [[ -n "$this_var" ]]; then
      echo "replacing instances of <REPLACE_WITH_MMR_${tenant^^}_${id^^}> with ${this_var}"
      # this sed command should replace all instances of the vars in kustomization.yaml and config/secret directories
      sed -i "s/<REPLACE_WITH_MMR_${id^^}>/${this_var}/g" \
        apps/mmr/overlays/${overlay_dir}/*.yaml \
        apps/mmr/overlays/${overlay_dir}/configs/*/* \
        apps/mmr/overlays/${overlay_dir}/secrets/*/*
    else
      echo "${domain_var}_${id} variable is unset!" 
      echo "skipping this substitution. please manually update your files,"
      echo "or update your variables.env file and rerun this script."
    fi
  done
else
  echo "you chose single-tenant deployment of matrix-media-repo. support for this is not ready yet. you're on your own, kid."
fi
