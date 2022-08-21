# Kubeconfigs
---

In this directory, we generate the kubeconfig files that will be used by the various
components of our cluster in order to communicate with the API server.

We generate the following kubeconfigs:
* admin.kubeconfig
* kube-scheduler.kubeconfig
* kube-controller-manager.kubeconfig
* kube-proxy.kubeconfig
* kubelet-<node-x>.kubeconfig


## Dependencies
---
In order to do this, we rely on having the `certificates` directory, with a Makefile
that generates all the required certificates. We also rely on it generating the ceritifactes
within a specific location, see inside the Makefile.

Also, we rely on having the `data.json` file well formatted in the parent directory.

## Usage
---

Just run:
```
$ make all
```

Eventually, this creates a `kubeconfigs` directory in which all the required kubeconfigs
are produced.

## Notes
---
The kubeconfigs contain the API server address. This is taken from the `data.json` file.
Note that only the first API server IP will be used !
