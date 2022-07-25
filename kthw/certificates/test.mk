
SHELL=/bin/bash
include ../.env

NODES=$(shell jq -r '.workers[].name' $(ROOT_DATA_FILE))

KUBELET_CERTS=$(patsubst %,$(CERTIFICATES_OUTPUT)/%/kubelet,$(NODES))
TMP=tmp
UTILS_SCRIPT=utils_test.sh
CONFIG_FILES_BASE=cert-configs

all:  $(KUBELET_CERTS)
#	echo $(KUBELET_CERTS)


$(CERTIFICATES_OUTPUT)/%/kubelet: $(TMP)/%.conf $(patsubst $(CERTIFICATES_OUTPUT)/%/kubelet,$(CERTIFICATES_OUTPUT)/%,$@)
	@mkdir -p "$(patsubst $(CERTIFICATES_OUTPUT)/%/kubelet,$(CERTIFICATES_OUTPUT)/%,$@)"
	@source $(UTILS_SCRIPT) && gen_certificate_generic $@ $(CERTIFICATES_OUTPUT)/ca.crt $(CERTIFICATES_OUTPUT)/ca.key $^ v3_ext

$(TMP):
	@mkdir $(TMP)

$(TMP)/%.conf: | $(TMP)
	@source $(UTILS_SCRIPT) && patch_kubelet_config_file $(patsubst $(TMP)/%.conf,%,$@) $(TMP) \
	 $(CONFIG_FILES_BASE)/kubelet.conf.template $(ROOT_DATA_FILE)

