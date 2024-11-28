#!/usr/bin/env bash

set -euo pipefail

. constants.env

multipass launch jammy \
    --cpus "$VM_CPUS" \
    --memory "$VM_MEMORY" \
    --disk "$VM_DISK" \
    --name "$VM_NAME"

multipass mount $(pwd)/helpers "$VM_NAME":"${VM_HOME}/helpers"
multipass mount $(pwd)/provision "$VM_NAME":"${VM_HOME}/provision"

multipass exec "$VM_NAME" -- "${VM_HOME}/provision/install-tools.sh" "$VM_HOME" "$VM_LB_IP_RANGE"
multipass exec "$VM_NAME" -- "${VM_HOME}/provision/create-aliases.sh"

multipass exec "$VM_NAME" -- "${VM_HOME}/provision/bootstrap-juju-controller.sh" "$VM_HOME"

multipass exec "$VM_NAME" -- "${VM_HOME}/provision/setup-iam.sh" "$VM_HOME" "$JIMM_DNS_NAME" "$WAIT_TIMEOUT"
multipass_vm_ip=$(multipass info --format json "$VM_NAME" | jq -r '.info."'"$VM_NAME"'".ipv4[0]')
iam_traefik_public_ip=$(multipass exec "$VM_NAME" -- "${VM_HOME}/helpers/show-iam-traefik-public-url.sh")
echo "Sudo password required to add the following route:"
echo "sudo ip route add ${iam_traefik_public_ip}/32 via $multipass_vm_ip"
sudo ip route add "${iam_traefik_public_ip}/32" via "$multipass_vm_ip"

multipass exec "$VM_NAME" -- "${VM_HOME}/provision/bootstrap-jimm.sh" "$JIMM_DNS_NAME" "$WAIT_TIMEOUT"
jimm_ingress_public_ip=$(multipass exec "$VM_NAME" -- "${VM_HOME}/helpers/show-jimm-ingress-public-url.sh")
echo "Sudo password required to add the following route:"
echo "sudo ip route add ${jimm_ingress_public_ip}/32 via $multipass_vm_ip"
sudo ip route add "${jimm_ingress_public_ip}/32" via "$multipass_vm_ip"

multipass exec "$VM_NAME" -- "${VM_HOME}/provision/onboard-controllers.sh" "$JIMM_ADMIN_EMAIL" "$JIMM_DNS_NAME"
