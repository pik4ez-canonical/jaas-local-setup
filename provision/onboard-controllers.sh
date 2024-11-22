#!/usr/bin/env bash

set -euo pipefail

JIMM_ADMIN_EMAIL="$1"

juju login test-jimm.localhost:443 -c jimm-k8s
juju switch jimm-demo-controller
juju config jimm controller-admins="$JIMM_ADMIN_EMAIL"

juju bootstrap microk8s staging-controller --config login-token-refresh-url=http://jimm-endpoints.jimm.svc.cluster.local:8080/.well-known/jwks.json
juju switch jimm-k8s
jimmctl controller-info staging-controller ~/snap/jimmctl/common/staging-controller-info.yaml --local --tls-hostname juju-apiserver
jimmctl add-controller ~/snap/jimmctl/common/staging-controller-info.yaml

juju switch staging-controller
juju add-model staging-model-1

juju bootstrap microk8s dev-controller --config login-token-refresh-url=http://jimm-endpoints.jimm.svc.cluster.local:8080/.well-known/jwks.json
juju switch jimm-k8s
jimmctl controller-info dev-controller ~/snap/jimmctl/common/dev-controller-info.yaml --local --tls-hostname juju-apiserver
jimmctl add-controller ~/snap/jimmctl/common/dev-controller-info.yaml

juju switch dev-controller
juju add-model dev-model-1
