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
SSL_COMMON         =ssl/ssl_commons.sh
TMP                =tmp
include ../.env

## Values
NODES          =$(shell jq -r '.workers[].name' $(ROOT_DATA_FILE))

## Targets
KUBELET_CERTS =$(patsubst %,%/kubelet.crt,$(NODES))
CERTIFICATES  =ca.crt admin.crt kubelets kube-controller-manager.crt kube-proxy.crt \
  kube-scheduler.crt service-accounts.crt kube-apiserver.crt $(KUBELET_CERTS)
CERT_TARGETS  =$(patsubst %,$(CERTIFICATES_OUTPUT)/%,$(CERTIFICATES))

TITLE=\e[0;44m
RESET=\e[0m

define echo_title
    echo -e "$(TITLE)=== $(1) $(RESET)"
endef

all: $(CERT_TARGETS)
	source $(KTHW_HOME)/lib && big_success "GENEARTED CERTIFICATES"

$(CERT_TARGETS): | $(CERTIFICATES_OUTPUT)

$(CERTIFICATES_OUTPUT):
	mkdir $@

ssl:
	git clone https://github.com/yoav-klein/ssl


$(CERTIFICATES_OUTPUT)/ca.crt: ssl
	@$(call echo_title, "generating $@")
	@source $(SSL_COMMON) && gen_ca_cert $(CERTIFICATES_OUTPUT) $(CONFIG_FILES_BASE)/ca.conf

$(CERTIFICATES_OUTPUT)/admin.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/admin.conf

$(CERTIFICATES_OUTPUT)/kube-controller-manager.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kube-controller-manager.conf

$(CERTIFICATES_OUTPUT)/kube-proxy.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kube-proxy.conf

$(CERTIFICATES_OUTPUT)/kube-scheduler.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/kube-scheduler.conf

$(CERTIFICATES_OUTPUT)/service-accounts.crt: $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $(CONFIG_FILES_BASE)/service-accounts.conf


$(TMP):
	@mkdir $(TMP)

## kube-apiserver related  targets

# target to create kube-apiserver.crt
$(CERTIFICATES_OUTPUT)/kube-apiserver.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(TMP)/kube-apiserver.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key tmp/kube-apiserver.conf v3_ext

$(TMP)/kube-apiserver.conf: $(ROOT_DATA_FILE) | $(TMP)
	@ROOT_CONFIG_FILE=$(ROOT_DATA_FILE) source $(UTILS_SCRIPT) && \
                      patch_apiserver_config $(CONFIG_FILES_BASE)/kube-apiserver.conf.template $(TMP)/kube-apiserver.conf


## kubelets related targets

# target to create certificates/worker<x>/kubelet.crt files
$(CERTIFICATES_OUTPUT)/%/kubelet.crt: $(TMP)/%.conf $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@mkdir -p "$(patsubst $(CERTIFICATES_OUTPUT)/%/kubelet.crt,$(CERTIFICATES_OUTPUT)/%,$@)"
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $< v3_ext

# target to generate the patched configuration file
$(TMP)/%.conf: $(ROOT_DATA_FILE) | $(TMP)
	@source $(UTILS_SCRIPT) && patch_kubelet_config_file $(patsubst $(TMP)/%.conf,%,$@) $(TMP) \
	 $(CONFIG_FILES_BASE)/kubelet.conf.template $(ROOT_DATA_FILE)


.PHONY: clean
clean:
	rm -rf $(CERTIFICATES_OUTPUT)/* $(TMP)
