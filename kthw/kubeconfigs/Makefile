SHELL=/bin/bash


## File locations
ROOT_CONFIG_FILE  =../data.json
UTILS_SCRIPT      =utils.sh
include ../.env

## Values
NODES          =$(shell jq -r '.workers[].name' $(ROOT_CONFIG_FILE))
APISERVER_IP   =$(shell jq '.apiServerAddress.publicIp' $(ROOT_CONFIG_FILE))
CLUSTER_NAME   =$(shell jq '.clusterName' $(ROOT_CONFIG_FILE))

## Targets
KUBELET_TARGETS    =$(patsubst %,kubelet-%.kubeconfig,$(NODES))
KUBECONFIGS        =admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig kube-proxy.kubeconfig $(KUBELET_TARGETS)
KUBECONFIG_TARGETS =$(patsubst %,$(KUBECONFIGS_OUTPUT)/%,$(KUBECONFIGS))

TITLE=\e[0;44m
RESET=\e[0m

define echo_title
    echo -e "$(TITLE)=== $(1) $(RESET)"
endef


all: $(KUBECONFIG_TARGETS)
	@source $(KTHW_HOME)/lib && big_success "GENERATED KUBECONFIGS"

$(CERTIFICATES_OUTPUT)/%.crt:
	@$(call echo_title, "generating $@")
	@make -C $(CERTIFICATES_DIR) $@

$(KUBECONFIGS_OUTPUT)/admin.kubeconfig: $(CERTIFICATES_OUTPUT)/admin.crt $(ROOT_DATA_FILE)
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "kube-admin" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $< $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)

$(KUBECONFIGS_OUTPUT)/kube-proxy.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-proxy.crt $(ROOT_DATA_FILE)
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-proxy" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)
 
$(KUBECONFIGS_OUTPUT)/kube-controller-manager.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-controller-manager.crt
	@$(call echo_title, "generating $@")
	source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-controller-manager" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)
    
$(KUBECONFIGS_OUTPUT)/kube-scheduler.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-scheduler.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-scheduler" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)

$(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig: $(CERTIFICATES_OUTPUT)/%/kubelet.crt
	@$(call echo_title, "generating $@")
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:node:$(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,%,$@)" \
        $(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,$(CERTIFICATES_OUTPUT)/%/kubelet.key,$@)


.PHONY: clean

clean:
	rm kubeconfigs/*
