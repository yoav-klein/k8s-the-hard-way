# Networking
---

In this part we configure networking for our cluster.

This includes 2 parts:
* Installing WeaveNet networking plugin
* Installing CoreDNS for DNS services

## WeaveNet

The network plugin takes care of networking in the cluster.
Until installing a network plugin, the nodes are in NotReady state.


### Run

```
$ ./networking.sh weavenet
```

After running this, the nodes should be in a Ready state:

```
$ kubectl get nodes

NAME      STATUS   ROLES    AGE   VERSION
worker1   Ready    <none>   29m   v1.24.3
worker2   Ready    <none>   29m   v1.24.3
```

## CoreDNS

CoreDNS provides DNS services in the cluster. It's basically an application running as pods
in the cluster, exposed as a service. 
Other pods in the cluster will access this service for DNS services by its IP address.

You may ask, how do the pods know the IP of this service?
This is configured in the `kubelet-config.yaml` file.

### Configuration
In the root data file, there is the `.versions.coredns` field, which will be used 
to install the required version of CoreDNS.

Also, the `.serviceIpRange` will be used. CoreDNS will be assigned 10 in the last octet 
in this range.

### Run

```
$ ./networking.sh coredns
```

### Test
After this, you should have DNS services in the cluster.

Run this to test:
```
$ kubectl run -it --image=yoavklein3/net-tools:latest
$ nslookup kubernetes

Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   kubernetes.default.svc.cluster.local
Address: 10.96.0.1

```


