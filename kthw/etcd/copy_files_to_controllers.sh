#!/bin/bash

source ../.env

username=$(jq -r ".machinesUsername" $ROOT_DATA_FILE)
controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))


copy_files_to_controllers() {
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        name=$(echo $controller | jq -r ".name")
        
        echo "ssh -i $SSH_PRIVATE_KEY \"$username@$ip\" \"mkdir -p ~/k8s/etcd\""
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" "mkdir -p ~/k8s/etcd"
       
        scp -i $SSH_PRIVATE_KEY "$name.etcd.service" "$username@$ip:~/k8s/etcd/etcd.service"
        scp -i $SSH_PRIVATE_KEY $CERTIFICATES_OUTPUT/ca.crt "$username@$ip:~/k8s/etcd/"
        scp -i $SSH_PRIVATE_KEY $CERTIFICATES_OUTPUT/kube-apiserver.crt "$username@$ip:~/k8s/etcd/"
        scp -i $SSH_PRIVATE_KEY $CERTIFICATES_OUTPUT/kube-apiserver.key "$username@$ip:~/k8s/etcd/"
        scp -i $SSH_PRIVATE_KEY ./setup.sh "$username@$ip:~/k8s/etcd"
    done
}

run_setup() {
    for controller in ${controllers[@]}; do
        ip=$(echo $controller | jq -r ".ip")
        ssh -i $SSH_PRIVATE_KEY "$username@$ip" ~/k8s/etcd/setup.sh
    done
}

copy_files_to_controllers
run_setup

# foreach controller node:
# 1. scp unit file
# 2. scp ca.crt, kube-apiserver.crt, kube-apiserver.key
# 3. scp setup script
