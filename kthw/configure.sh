#!/bin/bash

[ -f "./kthw_key" ] || { echo "Create a kthw_key file with the private key to access all machines"; exit 1 ; }
chmod 600 ./kthw_key

## Install kubectl
kubectl_version="v1.24.3"
# Install kubectl
curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
chmod +x ./kubectl
if ! ./kubectl 1>/dev/null; then echo "kubectl failed !!"; exit 1; fi
sudo mv ./kubectl /usr/local/bin

## Genearate a .env file 
sed  "s@{{pwd}}@$(pwd)@" env > .env

## Disable SSH strict host key checking
#sudo sed -i -E 's/#[[:space:]]*(StrictHostKeyChecking[[:space:]]*)ask/\1no/' /etc/ssh/ssh_config
echo "StrictHostKeyChecking no" > ~/.ssh/config

# clone logging library
git clone https://github.com/yoav-klein/bash

## Install required tools
sudo apt-get update
sudo apt-get install -y jq make

