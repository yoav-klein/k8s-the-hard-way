SHELL=/bin/bash

## File locations
ROOT_CONFIG_FILE  =data.json
UTILS_SCRIPT      =utils.sh
KUBECONFIG_DIR    =kubeconfigs

## Values
CERTIFICATES_DIR        =../certificates
CERTIFICATES_OUTPUT_DIR = $(CERTIFICATES_DIR)/certificates
KUBECONFIG_DIR =kubeconfigs
NODES          =$(shell jq -r '.workers[].name' $(ROOT_CONFIG_FILE))
APISERVER_IP   =$(shell jq '."apiserverIPs"[0]' $(ROOT_CONFIG_FILE))
CLUSTER_NAME   =$(shell jq '.clusterName' $(ROOT_CONFIG_FILE))

## Targets
KUBELET_TARGETS    =$(patsubst %,kubelet-%.kubeconfig,$(NODES))
#KUBECONFIGS        =admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig kube-proxy.kubeconfig $(KUBELET_TARGETS)
KUBECONFIG_TARGETS =$(patsubst %,$(KUBECONFIG_DIR)/%,$(KUBELET_TARGETS))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

all: $(KUBECONFIG_TARGETS)
	@echo $(KUBECONFIG_TARGETS)
	echo $(KUBECONFIGS)

$(KUBECONFIG_DIR)/kubelet-%.kubeconfig: $(CERTIFICATES_OUTPUT_DIR)/kubelets
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:node:$(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,%,$@)" \
        $(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT_DIR)/ca.crt $(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \
        $(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \


