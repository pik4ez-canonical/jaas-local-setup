#!/usr/bin/env bash

set -euo pipefail

cat <<EOT >>~/.bashrc

if [ -f ~/.custom_bash_aliases ]; then
. ~/.custom_bash_aliases
fi
EOT

cat <<EOT >>~/.custom_bash_aliases
alias k="kubectl"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kl="kubectl logs"

alias j="juju"
alias jst="juju status"
alias jl="juju debug-log"
EOT
