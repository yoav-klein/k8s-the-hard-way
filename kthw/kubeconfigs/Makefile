SHELL=/bin/bash


## File locations
include ../.env
UTILS_SCRIPT      =utils.sh

## Values
NODES          =$(shell jq -r '.workers[].name' $(ROOT_DATA_FILE))
APISERVER_IP   =$(shell jq '.apiServerAddress.publicIp' $(ROOT_DATA_FILE))
CLUSTER_NAME   =$(shell jq '.clusterName' $(ROOT_DATA_FILE))

## Targets
KUBELET_TARGETS    =$(patsubst %,kubelet-%.kubeconfig,$(NODES))
KUBECONFIGS        =admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig kube-proxy.kubeconfig $(KUBELET_TARGETS)
KUBECONFIG_TARGETS =$(patsubst %,$(KUBECONFIGS_OUTPUT)/%,$(KUBECONFIGS))



all: $(KUBECONFIG_TARGETS)
	@source $(LOG_LIB) && print_success "GENERATED KUBECONFIGS"

$(CERTIFICATES_OUTPUT)/%.crt:
	@make -C $(CERTIFICATES_DIR) $@

$(KUBECONFIGS_OUTPUT)/admin.kubeconfig: $(CERTIFICATES_OUTPUT)/admin.crt $(ROOT_DATA_FILE)
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "kube-admin" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $< $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)

$(KUBECONFIGS_OUTPUT)/kube-proxy.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-proxy.crt $(ROOT_DATA_FILE)
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-proxy" \
		$(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)
 
$(KUBECONFIGS_OUTPUT)/kube-controller-manager.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-controller-manager.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-controller-manager" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)
    
$(KUBECONFIGS_OUTPUT)/kube-scheduler.kubeconfig: $(CERTIFICATES_OUTPUT)/kube-scheduler.crt
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:kube-scheduler" "127.0.0.1" \
		$@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/%.kubeconfig,$(CERTIFICATES_OUTPUT)/%.key,$@)

$(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig: $(CERTIFICATES_OUTPUT)/%/kubelet.crt $(ROOT_DATA_FILE)
	@source $(UTILS_SCRIPT) && gen_kubeconfig $(CLUSTER_NAME) "system:node:$(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,%,$@)" \
        $(APISERVER_IP) $@ $(CERTIFICATES_OUTPUT)/ca.crt $<  $(patsubst $(KUBECONFIGS_OUTPUT)/kubelet-%.kubeconfig,$(CERTIFICATES_OUTPUT)/%/kubelet.key,$@)


.PHONY: clean

clean:
	rm kubeconfigs/*
