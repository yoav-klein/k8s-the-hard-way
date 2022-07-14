#!/bin/bash

kubectl_version="v1.24.3"
# Install kubectl
curl -LO "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
chmod +x ./kubectl

if ! ./kubectl 1>/dev/null; then echo "kubectl failed !!"; exit 1; fi

sudo mv ./kubectl /usr/local/bin

sed  "s@{{pwd}}@$(pwd)@" env > .env
cp -r vim/.vim vim/.vimrc ~
sudo apt-get update
sudo apt-get install -y jq make
