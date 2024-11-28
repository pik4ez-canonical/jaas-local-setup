#!/usr/bin/env bash

set -euo pipefail

JIMM_ADMIN_EMAIL="$1"
JIMM_DNS_NAME="$2"

CONTROLLER_JIMM="jimm-k8s"

CONTROLLER_DEV="dev-controller"
CONTROLLER_STAGING="staging-controller"

MODEL_DEV_1="dev-model-1"
MODEL_STAGING_1="staging-model-1"

juju login "${JIMM_DNS_NAME}:443" -c "$CONTROLLER_JIMM"
juju switch jimm-demo-controller
juju config jimm controller-admins="$JIMM_ADMIN_EMAIL"

juju bootstrap microk8s "$CONTROLLER_STAGING" --config login-token-refresh-url=http://jimm-endpoints.jimm.svc.cluster.local:8080/.well-known/jwks.json
juju switch "$CONTROLLER_JIMM"
jimmctl controller-info "$CONTROLLER_STAGING" ~/snap/jimmctl/common/"$CONTROLLER_STAGING"-info.yaml --local --tls-hostname juju-apiserver
jimmctl add-controller ~/snap/jimmctl/common/"$CONTROLLER_STAGING"-info.yaml

juju switch "$CONTROLLER_STAGING"
juju add-model "$MODEL_STAGING_1"
staging_model_1_uuid=$(juju show-model "$MODEL_STAGING_1" --format yaml | yq ."$MODEL_STAGING_1".model-uuid)

juju bootstrap microk8s "$CONTROLLER_DEV" --config login-token-refresh-url=http://jimm-endpoints.jimm.svc.cluster.local:8080/.well-known/jwks.json
juju switch "$CONTROLLER_JIMM"
jimmctl controller-info "$CONTROLLER_DEV" ~/snap/jimmctl/common/"$CONTROLLER_DEV"-info.yaml --local --tls-hostname juju-apiserver
jimmctl add-controller ~/snap/jimmctl/common/"$CONTROLLER_DEV"-info.yaml

juju switch "$CONTROLLER_DEV"
juju add-model "$MODEL_DEV_1"
dev_model_1_uuid=$(juju show-model "$MODEL_DEV_1" --format yaml | yq ."$MODEL_DEV_1".model-uuid)

juju switch "$CONTROLLER_JIMM"
juju update-credentials microk8s --controller "$CONTROLLER_JIMM"
jimmctl import-model "$CONTROLLER_STAGING" "$staging_model_1_uuid" --owner "$JIMM_ADMIN_EMAIL"
jimmctl import-model "$CONTROLLER_DEV" "$dev_model_1_uuid" --owner "$JIMM_ADMIN_EMAIL"
