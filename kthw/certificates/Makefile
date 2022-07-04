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

PKI_SCRIPT=pki.sh
SSL_COMMON=ssl/ssl_commons.sh
SHELL=/bin/bash
DEPLOYMENT=certificates
CONFIG_FILES_BASE=cert-configs
CERTIFICATES=ca.crt admin.crt kubelets kube-controller-manager.crt kube-proxy.crt \
             kube-scheduler.crt service-accounts.crt kube-apiserver.crt
            
TARGETS=$(patsubst %,$(DEPLOYMENT)/%,$(CERTIFICATES))

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

#all: admin.crt kubelet_certs kube-controller-manager.crt kube-proxy.crt \
#        kube-scheduler.crt kube-apiserver.crt service-accounts.crt

all: $(TARGETS)

ssl:
	git clone https://github.com/yoav-klein/ssl

$(DEPLOYMENT)/ca.crt: ssl
	@source $(SSL_COMMON) && gen_ca_cert $(DEPLOYMENT) $(CONFIG_FILES_BASE)/ca.conf
	@$(call log, "Generated CA certificate")

$(DEPLOYMENT)/admin.crt: $(DEPLOYMENT)/ca.crt
	@source $(PKI_SCRIPT) && gen_certificate_generic $(basename $@) $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key $(CONFIG_FILES_BASE)/admin.conf

$(DEPLOYMENT)/kube-controller-manager.crt: $(DEPLOYMENT)/ca.crt
	@source $(PKI_SCRIPT) && gen_certificate_generic $(basename $@) $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key $(CONFIG_FILES_BASE)/kube-controller-manager.conf

$(DEPLOYMENT)/kube-proxy.crt: $(DEPLOYMENT)/ca.crt
	@source $(PKI_SCRIPT) && gen_certificate_generic $(basename $@) $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key $(CONFIG_FILES_BASE)/kube-proxy.conf

$(DEPLOYMENT)/kube-scheduler.crt: $(DEPLOYMENT)/ca.crt
	@source $(PKI_SCRIPT) && gen_certificate_generic $(basename $@) $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key $(CONFIG_FILES_BASE)/kube-scheduler.conf

$(DEPLOYMENT)/service-accounts.crt: $(DEPLOYMENT)/ca.crt
	@source $(PKI_SCRIPT) && gen_certificate_generic $(basename $@) $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key $(CONFIG_FILES_BASE)/service-accounts.conf

$(DEPLOYMENT)/kubelets: $(DEPLOYMENT)/ca.crt
	@source $(PKI_SCRIPT) && generate_kubelet_client_certs $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key $(CONFIG_FILES_BASE)/kubelet.conf.template $@

$(DEPLOYMENT)/kube-apiserver.crt: $(DEPLOYMENT)/ca.crt
	@if [ ! -d tmp ]; then mkdir tmp; fi
	@source $(PKI_SCRIPT) && patch_apiserver_config $(CONFIG_FILES_BASE)/kube-apiserver.conf.template tmp/kube-apiserver.conf
	@source $(PKI_SCRIPT) && gen_certificate_generic $(basename $@) $(DEPLOYMENT)/ca.crt $(DEPLOYMENT)/ca.key tmp/kube-apiserver.conf v3_ext
	@rm -rf tmp

.PHONY: clean
clean:
	rm -rf $(DEPLOYMENT)/*
