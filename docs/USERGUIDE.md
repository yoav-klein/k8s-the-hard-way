# User Guide
---

This document will cover everything necessary for you to use this tool to bootstrap a cluster.

## Prerequisites
---

### Infrastructure
First, you need to have the following infrastructure:
* One or more machines to function as the kubernetes control plane
* One or more machines to function as worker nodes
* If you want to have a multi-controller control-plane, you must have a load balancer
  which load-balances traffic on port 6443. Will be explained below.

Your machines must have netwrok connectivity between them, of course.

### Machines SSH setup
The cluster bootstraping is all done from one of the nodes in the cluster, let's call it
the "manager" node. This doesn't have to be one of the nodes that you designate to be a
controller node in particular, just one of the nodes in the cluster.

All the bootstrapping is done via SSH commands. That means 
you need to perform the following steps on your machines:

1. On all nodes, have a user with the exact same name
2. Generate a SSH key-pair, nevermind where and how
3. Have the public key in the `authorized_keys` of this user on all nodes
4. On the manager node, put the private key in a file called `kthw_key` in the 
root of the project (i.e. the root of this repository)
5. You need to make sure that it is possible to run sudo commands without a password on each of the nodes.

NOTE: There's another thing we need to take care of, and this is to disable the known hosts prompt,
but we already take care of this in the configure script, see below. 

This will ensure that the manager node can perform SSH commands on all the nodes without 
requiring a password.

## Configuration data
---
After setting up the infrastructure, you need to fill in the details in the `data.json` file.
This file needs to contain all the details needed to bootstrap the cluster: IPs of the machines,
versions of the tools, etc.

These are the fields in the file:

`machinesUsername` - the username in all the machines, as mentioned above.
`clusterName` - not very important
`clusterCidr` - the IP range for pods in the cluster. Recommended to leave it as is.
`serviceIpRange` - IP range for services in the cluster. Recommended to leave it as is.
`workers` - a list of worker nodes. For each one, fill in a name, IP address, and domain name that the node is accessible with.
`controllers` - a list of controller nodes, same as workers.
`apiServerAddress` - This contains the following bits:
  - `publicIp` - the IP of the API server. In a single-controller cluster, this is the IP of the controller node. In a multi-controller cluster, this is the IP of the load balancer that load-balances the API servers.
  - `hostname` - The domain name of the API server. Same as for the IP about single- or multi-controller clusters.
  - `clusterIp` - The cluster IP of the API server. This must be within the range of the `serviceIpRange`, and should generally be the first
                  in that range.
`versions` - the versions of the different tools used in the cluster.

## Configure
---

After you've filled in the details in the `data.json` file, you need to source the configuration script:
```
$ source ./configure.sh
```


## Bootstrap
---

Basically you have 2 ways to bootstrap the cluster:

### The short way
Using the `kthwctl` tool, just run:
```
$ ./kthwctl bootstrap
```

### The long way
If you want for some reason to go for a more gradual approach, you go through 
all the steps that `kthwctl` goes manually, i.e.:
1. Create the certificates
2. Create the kubeconfig
3. Bootstrap ETCD
4. Bootstrap control plane
5. Bootstrap worker nodes
6. Configure networking and DNS

This is done by `cd`ing into each directory (`certificates`, `kubeconfigs`, etc.) and following the instructions
as instructed in each of them.


## Troubleshooting
---
Problems can always occur due to many reasons. The first thing you should check is whether you configured
the `data.json` file correctly. Make sure you filled in the IPs of your machines correctly, etc.

You can always try running `kthwctl bootstrap` again. it's safe - steps that are already taken will not be taken again.

If that didn't work, go with baby steps. Note what step the failure occured in, cd into the corresponding directory, and follow the instructions
in the directory to complete the step. This will give you a better understanding of what exactly went wrong.


## NOTES


