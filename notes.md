https://canonical-jaas-documentation.readthedocs-hosted.com/en/latest/tutorial/deploy_jaas_microk8s/#deploy-the-identity-bundle

- If change the IdP version from 0.2/edge to 0.3/edge, three units won't get active:
  - kratos-external-idp-integrator/0 (expected)
  - hydra/0 and identity-platform-login-ui-operator/0 (not expected)

---

After the VM has been running over a weekend:

```
$ jimmctl audit-events
{}
ERROR JIMM session token expired (session token invalid)

$ juju login -u dmitry.belov@canonical.com -c jimm-k8s
ERROR cannot log into controller "jimm-k8s": JIMM does not support login from old clients (not supported)
```

All units in both `jimm` and `iam` models are in an active/idle state.

Reported here: https://chat.canonical.com/canonical/pl/ar6p9jbpwffhtg86sn9g4qxjgc.
