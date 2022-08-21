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

This will ensure that the manage node can perform SSH commands on all the nodes without 
requiring a password.



