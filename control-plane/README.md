# Control Plane
---

This directory contains the contents needed to set up the control plane of kubernetes.

The control plane is composed of 3 components:
1. kube-apiserver
2. kube-scheduler
3. kube-controller-manager

Each is a separate binary, running as a service on the machine.

Basically the structure is very similar to the `etcd` component.

We have the `cp_agent.sh` script, which is installed on each controller machine,
containing a set of functions such as `install_binariers`, `intsall_services`, etc.
and then we have the `cp_manager.sh` which has a corresponding function for each function
in the agent script.

The manager script iterates over the controller nodes and executes the required function.

## Usage
---

Using the `cp_manager.sh` script, very similar to the etcd.

```
$ cp_manager.sh bootstrap
$ cp_manager.sh reset
```

Or the long ways:
```
$ cp_manager.sh build
$ cp_manager.sh distribute
$ cp_manager.sh install_binaries
$ cp_manager.sh install_services
$ cp_manager.sh start

$ cp_manager.sh stop
$ cp_manager.sh uninstall_services
$ cp_manager.sh uninstall_binaries
$ cp_manager.sh clean_nodes
```
