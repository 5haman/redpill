BIN_DIR = /usr/src/bin
RUN     = $(BIN_DIR)/run.sh
PKG     = $(BIN_DIR)/pkg.sh

default: all

all: pkg init dist

pkg:
	$(PKG) -d -p e2fsprogs
	$(PKG) skalibs
	$(PKG) execline
	$(PKG) s6
	$(PKG) s6-linux-utils
	$(PKG) s6-portable-utils
	$(PKG) s6-rc
	$(PKG) dhcpcd
	$(PKG) linux
	
init:
	#$(RUN) py_install
	#$(RUN) py_cleanup
	$(RUN) create_initrd
	#$(RUN) install_static
	$(RUN) init_root 
	#$(RUN) install_docker
	#$(RUN) install_portainer
	#$(RUN) install_unison

dist:
	$(RUN) prepare_iso
	$(RUN) make_iso
