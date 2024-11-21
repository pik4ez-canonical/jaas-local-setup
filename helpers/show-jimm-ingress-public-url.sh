#!/usr/bin/env bash

juju status -m jimm --format=json | jq -r '.applications.ingress.address'
