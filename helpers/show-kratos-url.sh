#!/usr/bin/env bash

juju run traefik-public/0 show-proxied-endpoints | yq '.proxied-endpoints' | jq -r '.kratos.url'
