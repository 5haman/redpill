NAME	      = dockervm
VERSION       = 0.2
KERNELVERSION = 4.4.39
VOLUME        = /opt/build
CACHE         = $(HOME)/.cache/dockervm
DEBUG         = false

FULLNAME  = $(NAME):$(VERSION)
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
		--build-arg debug=$(DEBUG) \
		-t $(FULLNAME) .

dist:
	rm -rf $(CACHE)/iso $(CACHE)/rootfs
	$(DOCKER) run -it --rm \
		-v $(CACHE):$(CACHE) \
		-v $(PWD):$(VOLUME) \
		-e KERNELVERSION=$(KERNELVERSION) \
		-e buildroot=$(VOLUME) \
	        -e buildcache=$(CACHE) \
	        -e version=$(VERSION) \
		-e debug=$(DEBUG) \
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
		-e buildroot=$(VOLUME) \
	        -e buildcache=$(CACHE) \
	        -e version=$(VERSION) \
		-e debug=$(DEBUG) \
		$(FULLNAME)

clean:
	rm -f pkgcache/init-*.pkg
	rm -f pkgcache/filesystem-*.pkg

test:
	mv .build/initrd .
	$(DOCKER) build -t $(FULLNAME)-test -f Dockerfile.test .
	mv initrd .build
	$(DOCKER) run -it --rm $(FULLNAME)-test

www:
	ls -la dist
	cd dist && $(PYTHON) -m SimpleHTTPServer 8000

box:
	qemu-img convert -f raw -O qcow2 dist/dockervm.iso dist/vagrant/dockervm.img
	rm -rf $(HOME)/.dockervm
	mkdir $(HOME)/.dockervm
	cd dist/vagrant && tar czf $(HOME)/.dockervm/dockervm.box metadata.json Vagrantfile dockervm.img
	vagrant box add iconlinux $(HOME)/.dockervm/dockervm.box --force --provider=libvirt
	cd $(HOME)/.dockervm \
	&& vagrant init -m dockervm  \
	&& vagrant up --provider=libvirt

.PHONY: build install dist
