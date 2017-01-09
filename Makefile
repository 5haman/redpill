NAME	  = dockervm
FULLNAME  = $(NAME):$(VERSION)
VERSION   = $(shell cat version)
DOCKER    = $(shell which docker)
PYTHON    = $(shell which python)
SRC_DIR   = /usr/src

default: build www

build:
	mkdir -p build
	chown -R root:root rootfs
	$(DOCKER) build \
		--build-arg SRC_DIR=$(SRC_DIR) \
		--build-arg VERSION=$(VERSION) \
		-t $(FULLNAME) .
	$(DOCKER) run -it --rm \
		-v $(PWD):$(SRC_DIR) \
		-v $(PWD)/build/modules:/lib/modules \
		-v $(PWD)/build/boot:/boot \
		$(FULLNAME) -c "make dist"

run:
	$(DOCKER) run -it --rm \
		-v $(PWD):$(SRC_DIR) \
		$(FULLNAME)

test:
	mv build/initrd .
	$(DOCKER) build -t $(FULLNAME)-test -f Dockerfile.test .
	mv initrd build
	$(DOCKER) run -it --rm --privileged $(FULLNAME)-test

www:
	ls -la dist
	cd dist && $(PYTHON) -m SimpleHTTPServer 8000

box:
	qemu-img convert -f raw -O qcow2 dist/iconlinux.iso dist/iconlinux.img
	rm -rf $(HOME)/.iconlinux
	mkdir $(HOME)/.iconlinux
	cd dist && tar czf $(HOME)/.iconlinux/iconlinux.box metadata.json Vagrantfile iconlinux.img
	vagrant box add iconlinux $(HOME)/.iconlinux/iconlinux.box --force --provider=libvirt
	cd $(HOME)/.iconlinux \
	&& vagrant init -m iconlinux  \
	&& vagrant up --provider=libvirt

.PHONY: build install
