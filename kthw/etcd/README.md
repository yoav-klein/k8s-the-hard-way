# ETCD
---

ETCD is a key-value data store used by kubernetes to store cluster state.

ETCD can run as a cluster of nodes. In KTHW, we run an instance of ETCD
on each controller node.

## How it works:

The `etcd_manager.sh` manages all the etcd-related operations.

The way it works is as such:
we have a set of files that needs to be copied to the controller machines, and then
run some operations on those machines. Eventually, we need to set up the etcd service.

One of those files is the `etcd_agent.sh`, which does all the work on the controller machines.
From the `etcd_manager.sh`, we distribute the files to the controllers, and then work with the
agent to do all the work.

Basically the steps we need to take are:
1. Render the service and agent files from the templates
2. Copy the files to the `ETCD_HOME` directory on the controllers
And on the controllers:
3. Install the etcd software and some prerequisites
4. Install the etcd service
5. Start the service

So the `etcd_manager` and `etcd_agent` have commands to do each of these steps individually.

In addition, the `etcd_manager` has the `bootstrap` and `reset` commands, which tries to 
do the whole thing from start to end.

## Usage

### Up
So, taking the long way, we'll do:
```
$ etcd_manager.sh create_deployment
$ etcd_manager.sh distribute
$ etcd_manager.sh install_binaries
$ etcd_manager.sh install_service
$ etcd_manager.sh start
```

Or the short way:
```
$ etcd_manager.sh bootstrap
```

### Down
The long way:
```
$ etcd_manager.sh stop
$ etcd_manager.sh uninstall_service
$ etcd_manager.sh uninstall_binaries
$ etcd_manager.sh clean_nodes
```

The short way:
```
$ etcd_manager.sh reset
```




