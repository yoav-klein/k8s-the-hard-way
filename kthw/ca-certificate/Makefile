
SHELL=/bin/bash

define log
    echo -e "\e[32;1m=== $(1) \e[0m"
endef

ca.crt:
	@source ssl/ssl_functions.sh && gen_ca_cert ca.conf
	@$(call log, "Generated CA certificate")
		
admin.key:
	source ssl/ssl_functions.sh && gen_private_key "admin.key"
	@$(call log, "Generated admin.key")
	
admin.csr: admin.key
	@source ssl/ssl_functions.sh && gen_sign_request "admin.key" "admin.csr" "admin.conf"
	@$(call log, "Generated admin.key")

admin.crt: admin.csr ca.crt
	@source ssl/ssl_functions.sh && sign_request "admin.csr" "ca.crt" "ca.key" "admin.crt"
	@$(call log, "Generated admin.crt")

kubelet_certs: ca.crt
	@source pki.sh && generate_kubelet_client_certs

.PHONY: clean
clean:
	rm *.crt *.csr *.key -rf kubelet_certs
