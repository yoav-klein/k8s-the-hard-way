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
CONTROLLERS    =$(shell jq -r '.controllers[].name' $(ROOT_DATA_FILE))

## Targets
KUBELET_CERTS =$(patsubst %,%/kubelet.crt,$(NODES))
ETCD_SERVER_CERTS =$(patsubst %,etcd-server-%.crt,$(CONTROLLERS))
CERTIFICATES  =ca.crt admin.crt kubelets kube-controller-manager.crt kube-proxy.crt \
  kube-scheduler.crt service-accounts.crt kube-apiserver.crt apiserver-etcd-client.crt \
  apiserver-kubelet-client.crt $(KUBELET_CERTS)  $(ETCD_SERVER_CERTS)
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
	@source $(SSL_COMMON) && gen_ca_cert $(basename $@) $(CONFIG_FILES_BASE)/ca.conf

$(CERTIFICATES_OUTPUT)/admin.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(CONFIG_FILES_BASE)/admin.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key \
		$(CONFIG_FILES_BASE)/admin.conf

$(CERTIFICATES_OUTPUT)/kube-controller-manager.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(CONFIG_FILES_BASE)/kube-controller-manager.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key \
		$(CONFIG_FILES_BASE)/kube-controller-manager.conf

$(CERTIFICATES_OUTPUT)/kube-proxy.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(CONFIG_FILES_BASE)/kube-proxy.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key \
		$(CONFIG_FILES_BASE)/kube-proxy.conf

$(CERTIFICATES_OUTPUT)/kube-scheduler.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(CONFIG_FILES_BASE)/kube-proxy.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key \
		$(CONFIG_FILES_BASE)/kube-scheduler.conf

$(CERTIFICATES_OUTPUT)/service-accounts.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(CONFIG_FILES_BASE)/service-accounts.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key \
	   	$(CONFIG_FILES_BASE)/service-accounts.conf

$(CERTIFICATES_OUTPUT)/apiserver-kubelet-client.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(CONFIG_FILES_BASE)/apiserver-kubelet-client.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key \
		$(CONFIG_FILES_BASE)/apiserver-kubelet-client.conf


$(TMP):
	@mkdir $(TMP)

## kube-apiserver related  targets

# target to create kube-apiserver.crt
$(CERTIFICATES_OUTPUT)/kube-apiserver.crt: $(CERTIFICATES_OUTPUT)/ca.crt $(TMP)/kube-apiserver.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key tmp/kube-apiserver.conf v3_ext

$(TMP)/kube-apiserver.conf: $(ROOT_DATA_FILE) | $(TMP)
	@$(call echo_title, "generating $@")
	@ROOT_CONFIG_FILE=$(ROOT_DATA_FILE) source $(UTILS_SCRIPT) && \
                      patch_apiserver_config $(CONFIG_FILES_BASE)/kube-apiserver.conf.template $@



## kubelets related targets

# target to create certificates/worker<x>/kubelet.crt files
$(CERTIFICATES_OUTPUT)/%/kubelet.crt: $(TMP)/%.conf $(CERTIFICATES_OUTPUT)/ca.crt
	@$(call echo_title, "generating $@")
	@mkdir -p "$(patsubst $(CERTIFICATES_OUTPUT)/%/kubelet.crt,$(CERTIFICATES_OUTPUT)/%,$@)"
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $< v3_ext

# target to generate the patched configuration file
$(TMP)/%.conf: $(ROOT_DATA_FILE) | $(TMP)
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && patch_kubelet_config_file $(patsubst $(TMP)/%.conf,%,$@) $@ \
	 $(CONFIG_FILES_BASE)/kubelet.conf.template $(ROOT_DATA_FILE)



######## etcd related targets

# etcd CA certificate
$(CERTIFICATES_OUTPUT)/ca-etcd.crt: ssl
	@$(call echo_title, "generating $@")
	@source $(SSL_COMMON) && gen_ca_cert $(basename $@) $(CONFIG_FILES_BASE)/ca-etcd.conf

$(TMP)/etcd-server-%.conf: $(ROOT_DATA_FILE) | $(TMP)
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && patch_etcd_config_file $(patsubst $(TMP)/etcd-server-%.conf,%,$@) $(CONFIG_FILES_BASE)/etcd-server.conf.template $@ $(ROOT_DATA_FILE)

$(CERTIFICATES_OUTPUT)/etcd-server-%.crt: $(TMP)/etcd-server-%.conf $(CERTIFICATES_OUTPUT)/ca-etcd.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca-etcd.crt $(CERTIFICATES_OUTPUT)/ca-etcd.key $< v3_ext

$(CERTIFICATES_OUTPUT)/apiserver-etcd-client.crt: $(CERTIFICATES_OUTPUT)/ca-etcd.crt $(CONFIG_FILES_BASE)/apiserver-etcd-client.conf
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_certificate_generic $(basename $@) $(CERTIFICATES_OUTPUT)/ca-etcd.crt $(CERTIFICATES_OUTPUT)/ca-etcd.key $(CONFIG_FILES_BASE)/apiserver-etcd-client.conf

.PHONY: clean
clean:
	rm -rf $(CERTIFICATES_OUTPUT)/* $(TMP)
