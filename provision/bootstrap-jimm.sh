#!/usr/bin/env bash

VM_HOME="$1"
JIMM_DNS_NAME="$2"
WAIT_TIMEOUT="$3"

juju add-model jimm
juju deploy juju-jimm-k8s --channel=3/edge jimm
juju deploy openfga-k8s --channel=2.0/stable openfga
juju deploy postgresql-k8s --channel=14/stable postgresql
juju deploy vault-k8s --channel=1.15/beta vault
juju deploy nginx-ingress-integrator --channel=latest/stable --trust ingress
juju relate jimm:nginx-route ingress
juju relate jimm:openfga openfga
juju relate jimm:database postgresql
juju relate jimm:vault vault
juju relate openfga:database postgresql

declare -a apps_to_check=(
    "postgresql"
    "openfga"
)
for app in "${apps_to_check[@]}"; do
    juju wait-for application "$app" --timeout="$WAIT_TIMEOUT"
done

juju relate jimm admin/iam.hydra
juju relate jimm admin/iam.self-signed-certificates
juju deploy self-signed-certificates jimm-cert
juju relate ingress jimm-cert
juju wait-for application jimm-cert --timeout="$WAIT_TIMEOUT"

vault_address=$(juju status vault/leader --format=yaml | yq '.applications.vault.address')
export VAULT_ADDR="https://${vault_address}:8200"
cert_juju_secret_id=$(juju secrets --format=yaml | yq 'to_entries | .[] | select(.value.label == "self-signed-vault-ca-certificate") | .key')
juju show-secret ${cert_juju_secret_id} --reveal --format=yaml | yq '.[].content.certificate' >vault.pem && echo "saved certificate contents to vault.pem"
export VAULT_CAPATH=$(pwd)/vault.pem
key_init=$(vault operator init -key-shares=1 -key-threshold=1)
export VAULT_TOKEN=$(echo "$key_init" | sed -n -e 's/.*Root Token: //p')
export UNSEAL_KEY=$(echo "$key_init" | sed -n -e 's/.*Unseal Key 1: //p')

vault operator unseal "$UNSEAL_KEY"
vault_secret_id=$(juju add-secret vault-token token="$VAULT_TOKEN")
juju grant-secret vault-token vault
juju run vault/leader authorize-charm secret-id="$vault_secret_id"
juju remove-secret "vault-token"

echo $UNSEAL_KEY >vault_unseal_key.txt
echo $VAULT_TOKEN >vault_token.txt

juju wait-for application vault --timeout="$WAIT_TIMEOUT"

bakery_keygen_output=$(go run github.com/go-macaroon-bakery/macaroon-bakery/cmd/bakery-keygen/v3@latest)
public_key=$(echo "$bakery_keygen_output" | jq -r '.public')
private_key=$(echo "$bakery_keygen_output" | jq -r '.private')
juju config jimm uuid=$(uuidgen)
juju config jimm dns-name="$JIMM_DNS_NAME"
juju config jimm public-key="${public_key}"
juju config jimm private-key="${private_key}"
juju config jimm juju-dashboard-location="http://${JIMM_DNS_NAME}/auth/whoami"

declare -a apps_to_check=(
    "jimm"
    "ingress"
)
for app in "${apps_to_check[@]}"; do
    juju wait-for application "$app" --timeout="$WAIT_TIMEOUT"
done
