BIN_DIR = /usr/src/bin
RUN     = $(BIN_DIR)/run.sh

default: dist

dist: deps rootfs iso

deps:
	$(RUN) download_e2fs
	$(RUN) download_deps
	$(RUN) download_s6
	$(RUN) download_dhcpcd
	$(RUN) build_kernel
	
rootfs:
	#$(RUN) py_install
	#$(RUN) py_cleanup
	$(RUN) create_initrd
	$(RUN) install_static
	$(RUN) init_root 
	#$(RUN) install_docker
	#$(RUN) install_portainer
	#$(RUN) install_unison

iso:
	$(RUN) prepare_iso
	$(RUN) make_iso
