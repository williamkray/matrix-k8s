#!/usr/bin/env bash
set -e

engine="$1"
if [[ -z "$engine" ]]; then
  echo "you must supply an engine, either minikube, doke, or lke"
  exit 1
fi

## versions of stuff
ingress_version="v0.47.0"

## bootstrap a kubernetes cluster with the necessary prereqs to run these matrix and related components

install_nginx-ingress() {
  echo "configuring ingress-nginx..."

  case $engine in
    minikube)
      minikube addons enable ingress
      ;;
    doke|lke)
      echo "downloading ingress-nginx manifest version ${ingress_version}"
      wget -O networking/deploy-ingress-nginx.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${ingress_version}/deploy/static/provider/do/deploy.yaml
      kubectl apply -f networking/deploy-ingress-nginx.yaml
      ;;
    *)
      echo "kubernetes engine is either not set, or unrecognized. exiting."
      exit 1
      ;;
  esac
}

install_prometheus() {
  echo "installing prometheus..."
}


install_nginx-ingress
#install_prometheus
