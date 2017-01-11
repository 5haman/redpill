NAME	  = dockervm
FULLNAME  = $(NAME):$(VERSION)
VERSION   = $(shell cat version)
DOCKER    = $(shell which docker)
PYTHON    = $(shell which python)
BLD       = $(shell which builder)
SRC_DIR   = /usr/src

default: all

all: build dist www

build:
	mkdir -p .build
	chown -R root:root src/rootfs
	$(DOCKER) build \
		--build-arg SRC_DIR=$(SRC_DIR) \
		--build-arg VERSION=$(VERSION) \
		-t $(FULLNAME) .

dist:
	$(DOCKER) run -it --rm \
		-v $(PWD):$(SRC_DIR) \
		$(FULLNAME) -c "make iso"

iso:
	$(BLD) make_root
	$(BLD) init_root
	$(BLD) prepare_iso
	$(BLD) make_iso

run:
	$(DOCKER) run -it --rm \
		-v $(PWD):$(SRC_DIR) \
		$(FULLNAME)

test:
	mv .build/initrd .
	$(DOCKER) build -t $(FULLNAME)-test -f Dockerfile.test .
	mv initrd .build
	$(DOCKER) run -it --rm --privileged $(FULLNAME)-test

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
