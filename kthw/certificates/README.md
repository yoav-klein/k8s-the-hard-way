# Generate Certificates
---

In this section, we're generating a bunch of TLS certificates to be used by the different parts
of the kubernetes cluster.

First, we generate a CA certificate, which will be used to sign all other certificates.

## Client Certificates
Overall, we generate the following client certificates:
* admin
* kube-controller-manager
* A certificate for each kubelet
* kube-proxy
* kube-scheduler

These certificates will be used by those components to authenticate to the API server.

## Server Certificate
Then, we generate the server certificate for the API server, to authenticate itself to the components.

We'll use the `ssl_functions.sh` script to generate the certificates.
Source this file to your shell session.

## Service Account Key Pair
Kubernetes uses a key pair to generate service account tokens.
So we need to create a certificate for that also.

## Usage
---

In order to generate all the certificates, fill in the `machines.json` file with the information 
about your worker nodes and control-plane nodes.

Then, we have a Makefile that will do everything for us, utilizing the `pki.sh` script.

```
$ make all
```
