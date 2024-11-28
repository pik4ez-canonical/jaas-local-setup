#!/usr/bin/env bash

set -euo pipefail

VM_HOME="$1"

mkdir -p "${VM_HOME}/.local/share"
juju bootstrap microk8s initial-controller
