# Certifiates and Kubeconfigs
---

In this section, we're generating a bunch of TLS certificates to be used by the different parts
of the kubernetes cluster.

We're also generating kubeconfigs that will be used by the different parts of the cluster.


## Client Certificates
First, we generate a CA certificate that will be used across the cluster.
Then, we generate the certificates.

Overall, we generate the following client certificates:
* admin
* kube-controller-manager
* A certificate for each kubelet
* kube-proxy
* kube-scheduler

These certificates will be used by those components to authenticate to the API server.

## Server Certificate
Then, we generate the server certificate for the API server, to authenticate itself to the components.

## Service Account Key Pair
Kubernetes uses a key pair to generate service account tokens.
So we need to create a certificate for that also.

## Usage
---
First, fill all the relevant data in `data.json`. This includes the list of worker nodes, the cluster name, 
the IP of the API server, etc.

Use the Makefile to generate the certificates:
```
$ make certificates
```

In order to generate the kubeconfigs, run:
```
$ make kubeconfigs
```

Or, to generate all:
```
$ make all
```

## Notes
---

It is possible to write several IPs for the API server in the `data.json` file. All these IPs will be included as `subjectAlNames` in the certificate
of the API server, so that it will be possible to access the API with each of them. But, only the first IP will be 
in the kubeconfigs as the `clusters[].server`

