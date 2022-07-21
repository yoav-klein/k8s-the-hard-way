# ETCD
---

ETCD is a key-value data store used by kubernetes to store cluster state.

ETCD can run as a cluster of nodes. In KTHW, we run an instance of ETCD
on each controller node.

## Usage:

The `etcd_manager.sh` manages all the etcd-related operations.
Basically, in order to have our ETCD up and running, we need to run:

```
$ ./etcd_manager.sh create_deployment # will generate all the required files
$ ./etcd_manager.sh distribute # will copy those files to controller nodes
$ ./etcd_manager.sh run_on_nodes # will install the service and start it on controller nodes
$ ./etcd_manager.sh test # test is ETCD is up and running

```

