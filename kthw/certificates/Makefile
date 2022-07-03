
PKI_SCRIPT=pki.sh
SSL_COMMON=ssl/ssl_commons.sh
SHELL=/bin/bash

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

all: admin.crt kubelet_certs kube-controller-manager.crt kube-proxy.crt \
        kube-scheduler.crt kube-apiserver.crt service-accounts.crt

ssl:
	git clone https://github.com/yoav-klein/ssl

ca.crt: ssl
	@source $(SSL_COMMON) && gen_ca_cert ca.conf
	@$(call log, "Generated CA certificate")

admin.crt: ca.crt
	@source $(PKI_SCRIPT) && generate_admin_cert

kubelet_certs: ca.crt
	@source $(PKI_SCRIPT) && generate_kubelet_client_certs

kube-controller-manager.crt: ca.crt
	@source $(PKI_SCRIPT) && generate_kube_ctrl_mgr_cert

kube-proxy.crt: ca.crt
	@source $(PKI_SCRIPT) && generate_kube_proxy_cert

kube-scheduler.crt: ca.crt
	@source $(PKI_SCRIPT) && generate_kube_scheduler_cert

kube-apiserver.crt: ca.crt
	@source $(PKI_SCRIPT) && generate_kube_apiserver_cert

service-accounts.crt: ca.crt
	@source $(PKI_SCRIPT) && generate_service_accounts_cert


.PHONY: clean
clean:
	rm *.crt *.srl  *.csr *.key -rf kubelet_certs
