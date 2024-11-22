---
https://canonical-jaas-documentation.readthedocs-hosted.com/en/latest/tutorial/deploy_jaas_microk8s/#deploy-the-identity-bundle
* If change the IdP version from 0.2/edge to 0.3/edge, three units won't get active:
    * kratos-external-idp-integrator/0 (expected)
    * hydra/0 and identity-platform-login-ui-operator/0 (not expected)

---
https://canonical-jaas-documentation.readthedocs-hosted.com/en/latest/tutorial/deploy_jaas_microk8s/#configure-jimm

After provisioning IAM and JIMM, it's possible to reach JIMM:
```
curl -k https://test-jimm.localhost/debug/info
{"GitCommit":"e5b47d62f3b58e81df605e6c643b866852b15e3f","Version":"v3.1.12"}
```

But it doesn't work without `-k`, certificate issue:
```
curl https://test-jimm.localhost/debug/info
curl: (60) SSL certificate problem: self-signed certificate in certificate chain
More details here: https://curl.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

The [hint](https://canonical-jaas-documentation.readthedocs-hosted.com/en/latest/tutorial/deploy_jaas_microk8s/#jimm-shows-invalid-certificate) from the tutorial didn't do the trick.

---
