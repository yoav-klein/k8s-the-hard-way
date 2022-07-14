SHELL=/bin/bash

## File locations
ROOT_CONFIG_FILE  =../data.json
UTILS_SCRIPT      =utils.sh
include ../.env

## Values
NODES          =$(shell jq -r '.workers[].name' $(ROOT_CONFIG_FILE))
APISERVER_IP   =$(shell jq '."apiserverIPs"[0]' $(ROOT_CONFIG_FILE))
CLUSTER_NAME   =$(shell jq '.clusterName' $(ROOT_CONFIG_FILE))

## Targets
KUBELET_TARGETS    =$(patsubst %,kubelet-%.kubeconfig,$(NODES))
KUBECONFIGS        =admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig kube-proxy.kubeconfig $(KUBELET_TARGETS)
KUBECONFIG_TARGETS =$(patsubst %,$(KUBECONFIGS_OUTPUT)/%,$(KUBECONFIGS))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef


all: $(KUBECONFIG_TARGETS)

$(CERTIFICATES_OUTPUT)/kubelets:
	make -C $(CERTIFICATES_DIR) all

$(CERTIFICATES_OUTPUT)/%.crt:
	make -C $(CERTIFICATES_DIR) all

$(KUBECONFIGS_OUTPUT)/admin.kubeconfig: $(CERTIFICATES_OUTPUT)/admin.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "kube-admin" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/admin.crt $(CERTIFICATES_OUTPUT)/admin.key

$(KUBECONFIGS_OUTPUT)/kube-proxy.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-proxy.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-proxy" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt \
		$(CERTIFICATES_OUTPUT)/kube-proxy.crt $(CERTIFICATES_OUTPUT)/kube-proxy.key
 
$(KUBECONFIGS_OUTPUT)/kube-controller-manager.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-controller-manager.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-controller-manager" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/kube-controller-manager.crt \
		$(CERTIFICATES_OUTPUT)/kube-controller-manager.key
    
$(KUBECONFIGS_OUTPUT)/kube-scheduler.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-scheduler.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-scheduler" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/kube-scheduler.crt \
		$(CERTIFICATES_OUTPUT)/kube-scheduler.key

$(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig: $(CERTIFICATES_OUTPUT)/kubelets
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:node:$(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,%,$@)" \
        $(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \
        $(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \

.PHONY: clean

clean:
	rm kubeconfigs/*
