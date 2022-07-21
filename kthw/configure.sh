#!/bin/bash


## Install kubectl
kubectl_version="v1.24.3"
# Install kubectl
curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
chmod +x ./kubectl
if ! ./kubectl 1>/dev/null; then echo "kubectl failed !!"; exit 1; fi
sudo mv ./kubectl /usr/local/bin

## Genearate a .env file 
sed  "s@{{pwd}}@$(pwd)@" env > .env

## Configure vim for convinience
cp -r vim/.vim vim/.vimrc ~

## Disable SSH strict host key checking
#sudo sed -i -E 's/#[[:space:]]*(StrictHostKeyChecking[[:space:]]*)ask/\1no/' /etc/ssh/ssh_config
echo "StrictHostKeyChecking no" > ~/.ssh/config


## configure git
git config --global user.email yoavklein25@gmail.com
git config --global user.email yoavklein25@gmail.com

## Install required tools
sudo apt-get update
sudo apt-get install -y jq make

