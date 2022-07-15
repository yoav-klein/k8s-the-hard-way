#!/bin/bash

source ../.env

controllers=($(jq -c ".controllers[]" $ROOT_DATA_FILE))
echo $controllers

for controller in ${controllers[@]}; do
    echo $controller
done

# foreach controller node:
# 1. scp unit file
# 2. scp ca.crt, kube-apiserver.crt, kube-apiserver.key
# 3. scp setup script
