#!/usr/bin/env bash

juju status -m iam --format=json | jq -r '.applications."traefik-public".address'
