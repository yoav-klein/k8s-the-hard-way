# Worker Nodes
---

This directory contains all that is needed to set up our worker nodes.

On each worker node, we have the following components:
1. containerd - a container runtime
2. kubelet - the software that communicates with the kubernetes control plane. 
This is basically the kubernetes "agent" on the worker nodes.
3. kube-proxy - a piece of software that handles networking in the cluster.


### Containerd
the process of setting up containerd is rather complex. Along with containerd,
we install `runc`, which is a lower-level container runtime, and `cni-plugins`,
which has something to do with container networking.


## Configuration
make sure you configure the IP and hostnames of your worker nodes in the
`.workers` section of the root data file (data.json). 

Also, you need to make sure you have the required versions of: 
- runc
- containerd
- cni-plugins

configured in the `.versions` section in the data file.


## Usage

In addition to the commands we have in etcd and control plane,
here we have another 2 commands: `install_prerequisites` and `uninstall_prerequisites`
which set up containerd and all its dependencies.

Other than that, it's the same `workers_manager.sh` script with the commands we
have in etcd and control plane:

```
$ workers_manager.sh build
$ workers_manager.sh distribute
$ workers_manager.sh install_prerequisites
$ workers_manager.sh install_binaries
$ workers_manager.sh install_services
$ wokresr_manager.sh start

# or
# workers_manager.sh bootstrap
``
