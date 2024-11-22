#!/usr/bin/env bash

VM_HOME="$1"
JIMM_DNS_NAME="$2"
WAIT_TIMEOUT="$3"

juju add-model iam
juju deploy identity-platform --trust --channel 0.2/edge
declare -a apps_to_check=(
    "postgresql-k8s"
    "self-signed-certificates"
    "traefik-admin"
    "traefik-public"
    "identity-platform-login-ui-operator"
    "hydra"
    "kratos"
)
for app in "${apps_to_check[@]}"; do
    juju wait-for application -m iam "$app" --timeout="$WAIT_TIMEOUT"
done

juju offer hydra:oauth
juju offer self-signed-certificates:send-ca-cert

kratos_url=$(juju run traefik-public/0 show-proxied-endpoints | yq '.proxied-endpoints' | jq -r '.kratos.url')
echo "Register a Github Application"
echo ""
echo "Open https://github.com/settings/applications/new."
echo "Set Application name, for example test-jimm-oauth."
echo "Set Homepage URL to https://${JIMM_DNS_NAME}."
echo "Set Authorization callback URL to ${kratos_url}/self-service/methods/oidc/callback/github."
echo "Leave Enable Device Flow unchecked."
echo ""
echo "On the next screen, click Generate a new client secret."

echo ""
client_id=""
read -p "Enter Client ID: " client_id
client_secret=""
read -p "Enter Client Secret: " client_secret

juju config kratos-external-idp-integrator \
    provider=github \
    client_id="$client_id" \
    client_secret="$client_secret" \
    provider_id=github \
    scope=user:email

juju wait-for application -m iam kratos-external-idp-integrator --timeout="$WAIT_TIMEOUT"
