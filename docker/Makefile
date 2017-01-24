CACHE         = $(HOME)/.cache/redpill
DOCKER    = $(shell which docker)
PYTHON    = $(shell which python)

default: all

all: clean build dist www

build:
	$(DOCKER) build \
		--build-arg buildroot=$(VOLUME) \
		--build-arg buildcache=$(CACHE) \
		--build-arg version=$(VERSION) \
		--build-arg KERNELVERSION=$(KERNELVERSION) \
		--build-arg DEBUG=$(DEBUG) \
		-t $(FULLNAME) .

dist:
	$(DOCKER) run -it --rm \
		-v $(CACHE):$(CACHE) \
		-v $(PWD):$(VOLUME) \
		-e KERNELVERSION=$(KERNELVERSION) \
		-e DEBUG=$(DEBUG) \
		-e buildroot=$(VOLUME) \
	        -e buildcache=$(CACHE) \
	        -e version=$(VERSION) \
		$(FULLNAME) builder

info:
	@echo
	@echo "Package cache: $(PWD)/pkgcache"
	@ls -la "$(PWD)/pkgcache"
	@echo
	@echo "Build cache: $(CACHE)"
	@ls -la "$(CACHE)"
	@echo

run:
	$(DOCKER) run -it --rm \
		-v $(CACHE):$(CACHE) \
		-v $(PWD):$(VOLUME) \
		-e KERNELVERSION=$(KERNELVERSION) \
		-e DEBUG=$(DEBUG) \
		-e buildroot=$(VOLUME) \
	        -e buildcache=$(CACHE) \
	        -e version=$(VERSION) \
		$(FULLNAME)

clean:
	rm -f package/.cache/init-*
	rm -f package/.cache/filesystem-*
	rm -f package/.cache/syslinux-*
	rm -rf $(CACHE)/iso $(CACHE)/rootfs $(CACHE)/squashfs
	rm -rf $(CACHE)/init-* $(CACHE)/filesystem-* $(CACHE)/syslinux-*

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
