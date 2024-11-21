#!/usr/bin/env bash

set -euo pipefail

. constants.env

multipass_vm_ip=$(multipass info --format json "$MULTIPASS_VM_NAME" | jq -r '.info."'"$MULTIPASS_VM_NAME"'".ipv4[0]')
iam_traefik_public_ip=$(multipass exec "$MULTIPASS_VM_NAME" -- /home/ubuntu/helpers/show-iam-traefik-public-url.sh)
jimm_ingress_public_ip=$(multipass exec "$MULTIPASS_VM_NAME" -- /home/ubuntu/helpers/show-jimm-ingress-public-url.sh)

echo "Sudo password might be required for removing IP routes."

echo "sudo ip route del ${iam_traefik_public_ip}/32 via $multipass_vm_ip"
ip r | grep "${iam_traefik_public_ip} via ${multipass_vm_ip}"
if [ "$?" = "0" ]; then
    sudo ip route del "${iam_traefik_public_ip}/32" via "$multipass_vm_ip"
fi

echo "sudo ip route del ${jimm_ingress_public_ip}/32 via $multipass_vm_ip"
ip r | grep "${jimm_ingress_public_ip} via ${multipass_vm_ip}"
if [ "$?" = "0" ]; then
    sudo ip route del "${jimm_ingress_public_ip}/32" via "$multipass_vm_ip"
fi

multipass delete -p "$MULTIPASS_VM_NAME"
