# ETCD
---

ETCD is a key-value data store used by kubernetes to store cluster state.

ETCD can run as a cluster of nodes. In KTHW, we run an instance of ETCD
on each controller node.

## Usage:

The `run.sh` script will do the followings:
1. Read the list of controllers from the root data file.
2. For each one, generate a systemd unit file
3. To each one, copy the systemd unit file, along with the `kube-apiserver` certificate and the CA certificate.
4. Run the `setup.sh` script on each node.
5. Run the `test` function to see that ETCD is up.

Just run the `run.sh` script.
```
$ ./run.sh
```
