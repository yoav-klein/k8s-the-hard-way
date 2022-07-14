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
CERTIFICATES_OUTPUT           =certificates
include ../.env

## Values
NODES          =$(shell jq -r '.workers[].name' $(CONFIG_FILE))
APISERVER_IP   =$(shell jq '."apiserverIPs"[0]' $(CONFIG_FILE))
CLUSTER_NAME   =$(shell jq '.clusterName' $(CONFIG_FILE))

## Targets
CERTIFICATES       =ca.crt admin.crt kubelets kube-controller-manager.crt kube-proxy.crt \
  kube-scheduler.crt service-accounts.crt kube-apiserver.crt
CERT_TARGETS       =$(patsubst %,$(CERTIFICATES_OUTPUT)/%,$(CERTIFICATES))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

all: $(CERTIFICATES_OUTPUT)  $(CERT_TARGETS)

$(CERTIFICATES_OUTPUT):
	mkdir $@

ssl:
	git clone https://github.com/yoav-klein/ssl

$(CERTIFICATES_OUTPUT)/ca.crt: ssl
	@source $(SSL_COMMON) && gen_ca_cert $(CERTIFICATES_OUTPUT) $(CONFIG_FILES_BASE)/ca.conf
	@$(call log, "Generated CA certificate")

$(CERTIFICATES_OUTPUT)/admin.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/admin.conf

$(CERTIFICATES_OUTPUT)/kube-controller-manager.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kube-controller-manager.conf

$(CERTIFICATES_OUTPUT)/kube-proxy.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kube-proxy.conf

$(CERTIFICATES_OUTPUT)/kube-scheduler.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kube-scheduler.conf

$(CERTIFICATES_OUTPUT)/service-accounts.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/service-accounts.conf

$(CERTIFICATES_OUTPUT)/kubelets: $(CERTIFICATES_OUTPUT)/ca.crt
	@ROOT_CONFIG_FILE=$(ROOT_CONFIG_FILE) source $(UTILS_SCRIPT) && \
                      generate_kubelet_client_certs $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kubelet.conf.template $@

$(CERTIFICATES_OUTPUT)/kube-apiserver.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@if [ ! -d tmp ]; then mkdir tmp; fi
	@ROOT_CONFIG_FILE=$(ROOT_CONFIG_FILE) source $(UTILS_SCRIPT) && \
                      patch_apiserver_config $(CONFIG_FILES_BASE)/kube-apiserver.conf.template tmp/kube-apiserver.conf
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key tmp/kube-apiserver.conf v3_ext
	@rm -rf tmp


.PHONY: clean
clean:
	rm -rf $(CERTIFICATES_OUTPUT)/*
