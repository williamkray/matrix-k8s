#!/usr/bin/env bash
set -e

engine="$1"
if [[ -z "$engine" ]]; then
  echo "you must supply an engine. supported kubernetes engines are:"
  echo -e "minikube\ndoke\nlke"
  echo "AWS EKS is currently not supported."
  exit 1
fi

## versions of stuff
ingress_version="v0.47.0"
prometheus_operator_version="v0.8.0"

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
      echo "kubernetes engine is unrecognized. exiting."
      exit 1
      ;;
  esac

  echo 'nginx ingress deployed to k8s!'
}

install_prometheus() {
  echo "installing prometheus operator..."
  mkdir -p bootstraps # just in case it's not there yet
  pushd bootstraps
    if [[ -d kube-prometheus ]]; then
      cd kube-prometheus
      git fetch
      git checkout ${prometheus_operator_version}
    else
      git clone https://github.com/prometheus-operator/kube-prometheus.git
      cd kube-prometheus
      git checkout ${prometheus_operator_version}
    fi
  popd
  kubectl apply -f bootstraps/kube-prometheus/manifests/setup
  until kubectl get servicemonitors --all-namespaces ; do
    date
    sleep 1
    echo ""
  done
  kubectl apply -f bootstraps/kube-prometheus/manifests
  echo 'prometheus operator deployed to k8s!'
}

## run the functions we've defined up above. comment any of these steps out if you don't want to do them.
install_nginx-ingress
install_prometheus
