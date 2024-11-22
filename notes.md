https://canonical-jaas-documentation.readthedocs-hosted.com/en/latest/tutorial/deploy_jaas_microk8s/#deploy-the-identity-bundle

- If change the IdP version from 0.2/edge to 0.3/edge, three units won't get active:
  - kratos-external-idp-integrator/0 (expected)
  - hydra/0 and identity-platform-login-ui-operator/0 (not expected)
