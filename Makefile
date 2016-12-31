NAME	  = hyperdock-build
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
		$(FULLNAME)
	ls -la install

install:
	mkdir -p $(HOME)/.hyperdock
	cp -R install/* $(HOME)/.hyperdock

www:
	$(PYTHON) -m SimpleHTTPServer 8000

test:
	mv build/initrd initrd
	$(DOCKER) build -t "$(FULLNAME)-test" -f Dockerfile.test .
	mv initrd build/initrd
	$(DOCKER) run -it --rm --privileged "$(FULLNAME)-test"

.PHONY: build install
