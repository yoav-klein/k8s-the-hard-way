SHELL=/bin/bash

## File locations
ROOT_CONFIG_FILE  =../data.json
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
KUBECONFIGS        =admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig kube-proxy.kubeconfig $(KUBELET_TARGETS)
KUBECONFIG_TARGETS =$(patsubst %,$(KUBECONFIG_DIR)/%,$(KUBECONFIGS))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef


all: $(KUBECONFIG_TARGETS)

$(CERTIFICATES_OUTPUT_DIR)/kubelets:
	make -C $(CERTIFICATES_DIR) all

$(CERTIFICATES_OUTPUT_DIR)/%.crt:
	make -C $(CERTIFICATES_DIR) all

$(KUBECONFIG_DIR)/admin.kubeconfig: $(CERTIFICATES_OUTPUT_DIR)/admin.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "kube-admin" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT_DIR)/ca.crt $(CERTIFICATES_OUTPUT_DIR)/admin.crt $(CERTIFICATES_OUTPUT_DIR)/admin.key

$(KUBECONFIG_DIR)/kube-proxy.kubeconfig: $(CERTIFICATES_OUTPUT_DIR)/kube-proxy.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-proxy" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT_DIR)/ca.crt \
		$(CERTIFICATES_OUTPUT_DIR)/kube-proxy.crt $(CERTIFICATES_OUTPUT_DIR)/kube-proxy.key
 
$(KUBECONFIG_DIR)/kube-controller-manager.kubeconfig: $(CERTIFICATES_OUTPUT_DIR)/kube-controller-manager.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-controller-manager" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT_DIR)/ca.crt $(CERTIFICATES_OUTPUT_DIR)/kube-controller-manager.crt \
		$(CERTIFICATES_OUTPUT_DIR)/kube-controller-manager.key
    
$(KUBECONFIG_DIR)/kube-scheduler.kubeconfig: $(CERTIFICATES_OUTPUT_DIR)/kube-scheduler.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-scheduler" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT_DIR)/ca.crt $(CERTIFICATES_OUTPUT_DIR)/kube-scheduler.crt \
		$(CERTIFICATES_OUTPUT_DIR)/kube-scheduler.key

$(KUBECONFIG_DIR)/kubelet-%.kubeconfig: $(CERTIFICATES_OUTPUT_DIR)/kubelets
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:node:$(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,%,$@)" \
        $(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT_DIR)/ca.crt $(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \
        $(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \

.PHONY: clean

clean:
	rm kubeconfigs/*
