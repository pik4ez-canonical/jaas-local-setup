#!/usr/bin/env bash

set -euo pipefail

. constants.env

multipass delete -p "$MULTIPASS_VM_NAME"
