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

## File locations
UTILS_SCRIPT       =utils.sh
CONFIG_FILES_BASE  =cert-configs
ROOT_CONFIG_FILE   =../data.json
SSL_COMMON         =ssl/ssl_commons.sh
CERT_DIR           =certificates

## Values
NODES          =$(shell jq -r '.workers[].name' $(CONFIG_FILE))
APISERVER_IP   =$(shell jq '."apiserverIPs"[0]' $(CONFIG_FILE))
CLUSTER_NAME   =$(shell jq '.clusterName' $(CONFIG_FILE))

## Targets
CERTIFICATES       =ca.crt admin.crt kubelets kube-controller-manager.crt kube-proxy.crt \
  kube-scheduler.crt service-accounts.crt kube-apiserver.crt
CERT_TARGETS       =$(patsubst %,$(CERT_DIR)/%,$(CERTIFICATES))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

all: $(CERT_DIR)  $(CERT_TARGETS)

$(CERT_DIR):
	mkdir $@

ssl:
	git clone https://github.com/yoav-klein/ssl

$(CERT_DIR)/ca.crt: ssl
	@source $(SSL_COMMON) && gen_ca_cert $(CERT_DIR) $(CONFIG_FILES_BASE)/ca.conf
	@$(call log, "Generated CA certificate")

$(CERT_DIR)/admin.crt: $(CERT_DIR)/ca.crt
	source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/admin.conf

$(CERT_DIR)/kube-controller-manager.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kube-controller-manager.conf

$(CERT_DIR)/kube-proxy.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kube-proxy.conf

$(CERT_DIR)/kube-scheduler.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kube-scheduler.conf

$(CERT_DIR)/service-accounts.crt: $(CERT_DIR)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/service-accounts.conf

$(CERT_DIR)/kubelets: $(CERT_DIR)/ca.crt
	@ROOT_CONFIG_FILE=$(ROOT_CONFIG_FILE) source $(UTILS_SCRIPT) && \
                      generate_kubelet_client_certs $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key $(CONFIG_FILES_BASE)/kubelet.conf.template $@

$(CERT_DIR)/kube-apiserver.crt: $(CERT_DIR)/ca.crt
	@if [ ! -d tmp ]; then mkdir tmp; fi
	@ROOT_CONFIG_FILE=$(ROOT_CONFIG_FILE) source $(UTILS_SCRIPT) && \
                      patch_apiserver_config $(CONFIG_FILES_BASE)/kube-apiserver.conf.template tmp/kube-apiserver.conf
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERT_DIR)/ca.crt $(CERT_DIR)/ca.key tmp/kube-apiserver.conf v3_ext
	@rm -rf tmp


.PHONY: clean
clean:
	rm -rf $(CERT_DIR)/*
