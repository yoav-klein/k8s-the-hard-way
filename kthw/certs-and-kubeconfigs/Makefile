#######################################
#
#	Makefile for generating cluster certificates
#
#	each target creates a different certificate+key
#	the makefile uses the pki.sh script to generate the certificates
#
# 	it creates a deployment directory in which all the certificates
#	are created in
#
#####################################

SHELL=/bin/bash

## Files
CONFIG_FILE=data.json
UTILS_SCRIPT=utils.sh
SSL_COMMON=ssl/ssl_commons.sh
CONFIG_FILES_BASE=cert-configs

## Values
CERT_DIR=certificates
KUBECONFIG_DIR=kubeconfigs
NODES=$(shell jq -r '.workers[].name' $(CONFIG_FILE))
APISERVER_IP=$(shell jq '."apiserverIPs"[0]' $(CONFIG_FILE))
CLUSTER_NAME=$(shell jq '.clusterName' $(CONFIG_FILE))

## Targets
CERTIFICATES=ca.crt admin.crt kubelets kube-controller-manager.crt kube-proxy.crt \
  kube-scheduler.crt service-accounts.crt kube-apiserver.crt
KUBECONFIGS=admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig kube-proxy.kubeconfig $(KUBELET_TARGETS)
CERT_TARGETS=$(patsubst %,$(CERT_DIR)/%,$(CERTIFICATES))
KUBELET_TARGETS=$(patsubst %,kubelet-%.kubeconfig,$(NODES))
KUBECONFIG_TARGETS=$(patsubst %,$(KUBECONFIG_DIR)/%,$(KUBECONFIGS))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

all: kubeconfigs certificates

certificates: $(CERT_TARGETS)

kubeconfigs: $(KUBECONFIG_TARGETS)

ssl:
	git clone https://github.com/yoav-klein/ssl

$(CERT_DIR)/ca.crt: ssl
	@source $(SSL_COMMON) && gen_ca_cert $(CERT_DIR) $(CONFIG_FILES_BASE)/ca.conf
	@$(call log, "Generated CA certificate")

$(CERT_DIR)/admin.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/admin.conf

$(CERT_DIR)/kube-controller-manager.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kube-controller-manager.conf

$(CERT_DIR)/kube-proxy.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kube-proxy.conf

$(CERT_DIR)/kube-scheduler.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kube-scheduler.conf

$(CERT_DIR)/service-accounts.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/service-accounts.conf

$(CERT_DIR)/kubelets: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && generate_kubelet_client_certs $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kubelet.conf.template $@

$(CERT_DIR)/kube-apiserver.crt: $(CERT_DIR)/ca.crt
	@if [ ! -d tmp ]; then mkdir tmp; fi
	@source $(UTILS_SCRIPT) && patch_apiserver_config $(CONFIG_FILES_BASE)/kube-apiserver.conf.template tmp/kube-apiserver.conf
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key tmp/kube-apiserver.conf v3_ext
	@rm -rf tmp



###########

kubelet-kubeconfigs: $(KUBELET_TARGETS)

$(KUBECONFIG_DIR)/admin.kubeconfig: $(CERT_DIR)/admin.crt	
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) kube-admin $(APISERVER_IP) $@ $(CERT_DIR)/ca.crt $(CERT_DIR)/admin.crt $(CERT_DIR)/admin.key

$(KUBECONFIG_DIR)/kube-proxy.kubeconfig: $(CERT_DIR)/kube-proxy.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) system:kube-proxy $(APISERVER_IP) $@ $(CERT_DIR)/ca.crt $(CERT_DIR)/kube-proxy.crt $(CERT_DIR)/kube-proxy.key
 
$(KUBECONFIG_DIR)/kube-controller-manager.kubeconfig: $(CERT_DIR)/kube-controller-manager.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) system:kube-controller-manager "127.0.0.1" $@ $(CERT_DIR)/ca.crt \
        $(CERT_DIR)/kube-controller-manager.crt $(CERT_DIR)/kube-controller-manager.key
    
$(KUBECONFIG_DIR)/kube-scheduler.kubeconfig: $(CERT_DIR)/kube-scheduler.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) system:kube-scheduler "127.0.0.1" $@ $(CERT_DIR)/ca.crt $(CERT_DIR)/kube-scheduler.crt $(CERT_DIR)/kube-scheduler.key

$(KUBECONFIG_DIR)/kubelet-%.kubeconfig: $(CERT_DIR)/kubelets
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:node:$(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,%,$@)" \
        $(APISERVER_IP) $@ $(CERT_DIR)/ca.crt $(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \
        $(patsubst $(KUBECONFIG_DIR)/kubelet-%.kubeconfig,$^/%,$@)/kubelet.crt \

.PHONY: clean
clean:
	rm -rf $(CERT_DIR)/* $(KUBECONFIG_DIR)/*
