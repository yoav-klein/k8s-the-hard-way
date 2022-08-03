#!/bin/bash

__configure_sourced__=1

[ -f "./kthw_key" ] || { echo "Create a kthw_key file with the private key to access all machines"; return 1 ; }
chmod 600 ./kthw_key

## Install required tools
sudo apt-get update
sudo apt-get install -y jq make


## Genearate a .env file 
sed  "s@{{pwd}}@$(pwd)@" env > .env
source .env

## Install kubectl
echo $ROOT_DATA_FILE
kubectl_version=$(jq -r '.versions.kubernetes' $ROOT_DATA_FILE)
echo $kubectl_version
curl -LO "https://dl.k8s.io/release/v${kubectl_version}/bin/linux/amd64/kubectl"
chmod +x ./kubectl
if ! ./kubectl 1>/dev/null; then echo "kubectl failed !!"; return 1; fi
sudo mv ./kubectl /usr/local/bin

## Disable SSH strict host key checking
#sudo sed -i -E 's/#[[:space:]]*(StrictHostKeyChecking[[:space:]]*)ask/\1no/' /etc/ssh/ssh_config
echo "StrictHostKeyChecking no" > ~/.ssh/config

# clone logging library
git clone https://github.com/yoav-klein/bash

# set hte KUBECONFIG environment variable
export KUBECONFIG=${KUBECONFIGS_OUTPUT}/admin.kubeconfig

# set up kubectl completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" > ~/.bashrc
