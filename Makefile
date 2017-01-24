NAME = redpill
V = 0.2
FULLNAME = $(NAME):$(V)

DEBUG = false
BUILDROOT_VER = 2016.11.1
LINUX = 4.4.39+

WORKDIR  = $(PWD)/local
CACHE    = $(WORKDIR)/build
CACHEPKG = $(WORKDIR)/package
BUILDROOT= $(WORKDIR)/buildroot
ROOTFS   = $(WORKDIR)/rootfs
ISODIR   = $(WORKDIR)/iso
BUILDDIR = /opt/build

DOCKER=$(shell which docker)
PYTHON=$(shell which python)

default: all

all: clean buildroot build dist www

info:
	@echo " => Installed binaries:"
	@echo
	@echo " => Build cache: $(CACHE)"
	@ls -la "$(CACHE)"
	@echo
	@echo " => Package cache: $(CACHEPKG)"
	@ls -la "$(CACHEPKG)"
	@echo

buildroot:
	$(DOCKER) build \
	    --build-arg BUILDROOT_VER=$(BUILDROOT_VER) \
	    --build-arg BUILDDIR=$(BUILDDIR) \
	    -t $(NAME)-buildroot:$(V) -f Dockerfile.buildroot .

	mkdir -p $(BUILDROOT)
	rm -rf $(ROOTFS)

	cp -f config/buildroot/.config $(BUILDROOT)/.config \
	&& $(DOCKER) run -it --rm \
	    -v $(ROOTFS):/rootfs \
	    -v $(BUILDROOT):$(BUILDDIR)/output \
    	    $(NAME)-buildroot:$(V) \
	    /buildroot.sh \
	&& cp -f $(BUILDROOT)/.config config/buildroot/.config

brshell:
	$(DOCKER) run -it --rm \
	    -v $(ROOTFS):/rootfs \
	    -v $(BUILDROOT):$(BUILDDIR)/output \
    	    $(NAME)-buildroot:$(V) \
	    bash
	
build:
	$(DOCKER) build \
	    --build-arg version=$(V) \
	    --build-arg KERNELVERSION=$(LINUX) \
	    --build-arg BUILDDIR=$(BUILDDIR) \
	    --build-arg DEBUG=$(DEBUG) \
	    -t $(FULLNAME) .

dist:
	rm -rf $(ISODIR)

	$(DOCKER) run -it --rm \
	    -v $(ISODIR):/iso \
	    -v $(ROOTFS):/rootfs \
	    -v $(PWD):$(BUILDDIR)\
            -e version=$(V) \
	    -e KERNELVERSION=$(LINUX) \
	    -e DEBUG=$(DEBUG) \
	    $(FULLNAME) $(BUILDDIR)/bin/make_iso.sh

shell:
	$(DOCKER) run -it --rm \
	    -v $(ISODIR):/iso \
	    -v $(ROOTFS):/rootfs \
	     -v $(PWD):$(BUILDDIR) \
            -e version=$(V) \
	    -e KERNELVERSION=$(LINUX) \
	    -e DEBUG=$(DEBUG) \
	    $(FULLNAME)

clean:
	rm -rf $(CACHEPKG)/init* \
               $(CACHEPKG)/filesystem* \
               $(CACHEPKG)/syslinux* \
               $(CACHE)/init* \
               $(CACHE)/filesystem* \
               $(ISODIR) \
               $(ROOTFS)

brclean:	
	(cd local/buildroot/build && find -type d -maxdepth 1 | grep -vE "buildroot|toolchain|linux-headers|host-" | xargs rm -rf) || true

www:
	ls -la dist
	cd dist && $(PYTHON) -m SimpleHTTPServer 8000

box:
	qemu-img convert -f raw -O qcow2 dist/redpill.iso dist/vagrant/redpill.img
	rm -rf $(HOME)/.redpill
	mkdir $(HOME)/.redpill
	cd dist/vagrant && tar czf $(HOME)/.redpill/redpill.box metadata.json Vagrantfile redpill.img
	vagrant box add iconlinux $(HOME)/.redpill/redpill.box --force --provider=libvirt
	cd $(HOME)/.redpill \
	&& vagrant init -m redpill  \
	&& vagrant up --provider=libvirt

.PHONY: build install dist
