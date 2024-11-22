#!/usr/bin/env bash

set -euo pipefail

VM_HOME="$1"
VM_LB_IP_RANGE="$2"

sudo snap install jq
sudo snap install yq

sudo snap install microk8s --channel=1.28-strict/stable
sudo snap install juju --channel=3.5/stable

sudo usermod -a -G snap_microk8s ubuntu
mkdir "${VM_HOME}/.kube"
sudo chown -f -R ubuntu "${VM_HOME}/.kube"
sudo microk8s enable hostpath-storage dns ingress host-access
sudo microk8s enable metallb:"$VM_LB_IP_RANGE"
sudo snap alias microk8s.kubectl kubectl

sudo snap install go --classic
sudo snap install vault

sudo snap install jimmctl --channel=3/stable
sudo snap install jaas --channel=3/stable
