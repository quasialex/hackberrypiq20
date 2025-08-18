# --- Hackberry CM5 MAX17048 driver Makefile (safe: no config.txt edits by default)

obj-m += hackberrypi-max17048.o

DT_NAME := hackberrypicm5
MODULE_NAME := hackberrypi-max17048.ko

CONFIG_TXT := /boot/firmware/config.txt
OVERLAY_DIR := /boot/firmware/overlays
MODULE_INSTALL_DIR := /lib/modules/$(shell uname -r)/kernel/drivers/power/supply

.PHONY: modules clean install remove enable-overlay disable-overlay

modules:
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
	dtc -I dts -O dtb -o $(DT_NAME).dtbo $(DT_NAME).dts

clean:
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	rm -f *.dtbo

# Default install: install module + overlay, run depmod.
# DOES NOT touch config.txt anymore.
install: remove
	install -m 644 -D $(MODULE_NAME) $(MODULE_INSTALL_DIR)
	install -m 644 -D $(DT_NAME).dtbo $(OVERLAY_DIR)
	depmod -a
	@echo "Installed $(MODULE_NAME) to $(MODULE_INSTALL_DIR)"
	@echo "Installed $(DT_NAME).dtbo to $(OVERLAY_DIR)"
	@echo
	@echo "NOTE: Not modifying $(CONFIG_TXT)."
	@echo "If you need to enable the overlay entry, run: sudo make enable-overlay"

# Optional: explicitly add dtoverlay line if not present
enable-overlay:
	@if [ -f "$(CONFIG_TXT)" ]; then \
		if ! grep -qE '^[[:space:]]*dtoverlay=$(DT_NAME)([[:space:]]|$$)' "$(CONFIG_TXT)"; then \
			echo "dtoverlay=$(DT_NAME)" | sudo tee -a "$(CONFIG_TXT)" >/dev/null; \
			echo "Added dtoverlay=$(DT_NAME) to $(CONFIG_TXT)"; \
		else \
			echo "dtoverlay=$(DT_NAME) already present in $(CONFIG_TXT), skipping."; \
		fi \
	else \
		echo "$(CONFIG_TXT) not found. Create it and re-run make enable-overlay."; \
		exit 1; \
	fi

# Optional: remove dtoverlay line if present
disable-overlay:
	@if [ -f "$(CONFIG_TXT)" ]; then \
		sudo sed -i '/^[[:space:]]*dtoverlay=$(DT_NAME)\([[:space:]]\|$$\)/d' "$(CONFIG_TXT)"; \
		echo "Removed dtoverlay=$(DT_NAME) from $(CONFIG_TXT) (if it was present)."; \
	else \
		echo "$(CONFIG_TXT) not found. Nothing to remove."; \
	fi

# Uninstall files we installed; also clean config.txt line if you had added it before
remove:
	-rm -f "$(MODULE_INSTALL_DIR)/$(MODULE_NAME)"
	-rm -f "$(OVERLAY_DIR)/$(DT_NAME).dtbo"
	@if [ -f "$(CONFIG_TXT)" ]; then \
		sudo sed -i '/^[[:space:]]*dtoverlay=$(DT_NAME)\([[:space:]]\|$$\)/d' "$(CONFIG_TXT)"; \
	fi
