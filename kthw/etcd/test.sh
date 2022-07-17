#!/bin/bash

source ../.env

test() {
    export ETCD_API=3
   etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=$CERTIFICATES_OUTPUT/ca.crt \
  --cert=$CERTIFICATES_OUTPUT/kube-apiserver.crt \
  --key=$CERTIFICATES_OUTPUT/kube-apiserver.key
}

test
