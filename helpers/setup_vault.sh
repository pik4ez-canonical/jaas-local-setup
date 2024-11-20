#!/usr/bin/env bash

sudo snap install vault

export VAULT_ADDR=https://$(juju status vault/leader --format=yaml | yq '.applications.vault.address'):8200
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
