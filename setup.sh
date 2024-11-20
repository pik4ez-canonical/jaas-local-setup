#!/usr/bin/env bash

set -euo pipefail

. constants.env

multipass launch jammy \
    --cpus "$MULTIPASS_VM_CPUS" \
    --memory "$MULTIPASS_VM_MEMORY" \
    --disk "$MULTIPASS_VM_DISK" \
    --name "$MULTIPASS_VM_NAME"

multipass mount $(pwd)/helpers "$MULTIPASS_VM_NAME":/home/ubuntu/helpers

multipass exec "$MULTIPASS_VM_NAME" -- sudo snap install jq
multipass exec "$MULTIPASS_VM_NAME" -- sudo snap install yq

multipass exec "$MULTIPASS_VM_NAME" -- sudo snap install microk8s --channel=1.28-strict/stable
multipass exec "$MULTIPASS_VM_NAME" -- sudo snap install juju --channel=3.5/stable

multipass exec "$MULTIPASS_VM_NAME" -- sudo usermod -a -G snap_microk8s ubuntu
multipass exec "$MULTIPASS_VM_NAME" -- mkdir /home/ubuntu/.kube
multipass exec "$MULTIPASS_VM_NAME" -- sudo chown -f -R ubuntu /home/ubuntu/.kube
multipass exec "$MULTIPASS_VM_NAME" -- sudo microk8s enable hostpath-storage dns ingress host-access
multipass exec "$MULTIPASS_VM_NAME" -- sudo microk8s enable metallb:"$MULTIPASS_VM_LB_IP_RANGE"
multipass exec "$MULTIPASS_VM_NAME" -- sudo snap alias microk8s.kubectl kubectl

multipass exec "$MULTIPASS_VM_NAME" -- mkdir -p /home/ubuntu/.local/share
multipass exec "$MULTIPASS_VM_NAME" -- juju bootstrap microk8s jimm-demo-controller

multipass exec "$MULTIPASS_VM_NAME" -- juju add-model iam
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy identity-platform --trust --channel 0.2/edge
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
    multipass exec "$MULTIPASS_VM_NAME" -- juju wait-for application -m iam "$app" --timeout="$WAIT_TIMEOUT"
done

multipass exec "$MULTIPASS_VM_NAME" -- juju offer hydra:oauth
multipass exec "$MULTIPASS_VM_NAME" -- juju offer self-signed-certificates:send-ca-cert

kratos_url=$(multipass exec "$MULTIPASS_VM_NAME" -- /home/ubuntu/helpers/show-kratos-url.sh)
echo "Register a Github Application"
echo ""
echo "Open https://github.com/settings/applications/new."
echo "Enter an Application name, for example test-jaas."
echo "Set Homepage URL, for example https://test-jaas.localhost."
echo "Set Authorization callback URL to ${kratos_url}/self-service/methods/oidc/callback/github."
echo "Leave Enable Device Flow unchecked."
echo ""
echo "On the next screen, click Generate a new client secret."

echo ""
client_id=""
read -p "Enter Client ID: " client_id
client_secret=""
read -p "Enter Client Secret: " client_secret

multipass exec "$MULTIPASS_VM_NAME" -- juju config kratos-external-idp-integrator \
    provider=github \
    client_id="$client_id" \
    client_secret="$client_secret" \
    provider_id=github \
    scope=user:email

multipass exec "$MULTIPASS_VM_NAME" -- juju wait-for application -m iam kratos-external-idp-integrator --timeout="$WAIT_TIMEOUT"

multipass_vm_ip=$(multipass info --format json "$MULTIPASS_VM_NAME" | jq -r '.info."'"$MULTIPASS_VM_NAME"'".ipv4[0]')
traefik_public_ip=$(multipass exec "$MULTIPASS_VM_NAME" -- /home/ubuntu/helpers/show-traefik-public-url.sh)

echo "Sudo password required to add the following route:"
echo "sudo ip route add ${traefik_public_ip}/32 via $multipass_vm_ip"
sudo ip route add "${traefik_public_ip}/32" via "$multipass_vm_ip"

multipass exec "$MULTIPASS_VM_NAME" -- juju add-model jimm
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy -m jimm juju-jimm-k8s --channel=3/edge jimm
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy -m jimm openfga-k8s --channel=2.0/stable openfga
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy -m jimm postgresql-k8s --channel=14/stable postgresql
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy -m jimm vault-k8s --channel=1.15/beta vault
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy -m jimm nginx-ingress-integrator --channel=latest/stable --trust ingress
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm jimm:nginx-route ingress
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm jimm:openfga openfga
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm jimm:database postgresql
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm jimm:vault vault
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm openfga:database postgresql

declare -a apps_to_check=(
    "postgresql"
    "openfga"
)
for app in "${apps_to_check[@]}"; do
    multipass exec "$MULTIPASS_VM_NAME" -- juju wait-for application -m jimm "$app" --timeout="$WAIT_TIMEOUT"
done

multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm jimm admin/iam.hydra
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm jimm admin/iam.self-signed-certificates
multipass exec "$MULTIPASS_VM_NAME" -- juju deploy -m jimm self-signed-certificates jimm-cert
multipass exec "$MULTIPASS_VM_NAME" -- juju relate -m jimm ingress jimm-cert
multipass exec "$MULTIPASS_VM_NAME" -- juju wait-for application -m jimm jimm-cert --timeout="$WAIT_TIMEOUT"

multipass exec "$MULTIPASS_VM_NAME" -- /home/ubuntu/helpers/setup_vault.sh
multipass exec "$MULTIPASS_VM_NAME" -- juju wait-for application -m jimm vault --timeout="$WAIT_TIMEOUT"

multipass exec "$MULTIPASS_VM_NAME" -- sudo snap install go --classic
keygen_output=$(multipass exec "$MULTIPASS_VM_NAME" -- go run github.com/go-macaroon-bakery/macaroon-bakery/cmd/bakery-keygen/v3@latest)
public_key=$(echo "$keygen_output" | jq -r '.public')
private_key=$(echo "$keygen_output" | jq -r '.private')
multipass exec "$MULTIPASS_VM_NAME" -- juju config jimm uuid=$(uuidgen)
# TODO remove hardcoded DNS name.
multipass exec "$MULTIPASS_VM_NAME" -- juju config jimm dns-name=test-jaas.localhost
multipass exec "$MULTIPASS_VM_NAME" -- juju config jimm public-key="${public-key}"
multipass exec "$MULTIPASS_VM_NAME" -- juju config jimm private-key="${private-key}"

declare -a apps_to_check=(
    "jimm"
    "ingress"
)
for app in "${apps_to_check[@]}"; do
    multipass exec "$MULTIPASS_VM_NAME" -- juju wait-for application -m jimm "$app" --timeout="$WAIT_TIMEOUT"
done
