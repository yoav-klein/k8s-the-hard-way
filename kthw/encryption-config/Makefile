SHELL=/bin/bash

include ../.env

TARGET=$(ENCRYPTION_CONFIG_DIR)/encryption-config.yaml

$(TARGET): utils.sh
	source utils.sh && generate_file

clean:
	rm $(TARGET)

