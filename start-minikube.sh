#!/usr/bin/env bash

## this script runs the appropriate minikube command to start a minikube cluster from scratch
## with the flags needed by kube-prometheus

minikube delete
minikube start \
  --nodes 3 \
  --kubernetes-version=v1.20.0 \
  --memory=6g \
  --bootstrapper=kubeadm \
  --extra-config=kubelet.authentication-token-webhook=true \
  --extra-config=kubelet.authorization-mode=Webhook \
  --extra-config=scheduler.address=0.0.0.0 \
  --extra-config=controller-manager.address=0.0.0.0

