#!/bin/bash

source ../lib
source ../.env

test() {
   export ETCD_API=3
   output=$(etcdctl member list --write-out=json  \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=$CERTIFICATES_OUTPUT/ca.crt \
  --cert=$CERTIFICATES_OUTPUT/kube-apiserver.crt \
  --key=$CERTIFICATES_OUTPUT/kube-apiserver.key)
    
   echo $output
   num_members=$(echo $output | jq ".members | length")
   expected=$(jq ".controllers | length" $ROOT_DATA_FILE)

   if [ "$num_members" = "$expected" ]; then
       return 0
   else
       return 1
   fi
}

if test; then
    big_success "ETCD IS UP"
else
    log_error "ETCD failed starting !"
fi
