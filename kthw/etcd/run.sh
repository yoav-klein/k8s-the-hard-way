#!/bin/bash

source ../.env

sudo mkdir -p /etc/etcd /var/lib/etcd

sudo cp $CERTIFICATES_OUTPUT/ca.crt \
    $CERTIFICATES_OUTPUT/kube-apiserver.crt \
    $CERTIFICATES_OUTPUT/kube-apiserver.key  \
    /etc/etcd


