#!/usr/bin/env bash

set -euo pipefail

. constants.env

multipass_vm_ip=$(multipass info --format json "$MULTIPASS_VM_NAME" | jq -r '.info."'"$MULTIPASS_VM_NAME"'".ipv4[0]')
echo "VM IP ${multipass_vm_ip}"
traefik_public_ip=$(multipass exec "$MULTIPASS_VM_NAME" -- /home/ubuntu/helpers/show-traefik-public-url.sh)
echo "Traefik public IP ${traefik_public_ip}"

sudo ip route del "${traefik_public_ip}/32" via "$multipass_vm_ip"

multipass delete -p "$MULTIPASS_VM_NAME"
