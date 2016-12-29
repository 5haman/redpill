NAME	  = hyperdock-build
VERSION   = $(shell cat version)
DOCKER    = $(shell which docker)
FULLNAME  = $(NAME):$(VERSION)
SRC_DIR   = /usr/src

default: build

build:
	mkdir -p build
	$(DOCKER) build \
		--build-arg SRC_DIR=$(SRC_DIR) \
		--build-arg VERSION=$(VERSION) \
		-t $(FULLNAME) .
	$(DOCKER) run -it --rm \
		-v $(PWD):$(SRC_DIR) \
		$(FULLNAME)

install:
	mkdir -p $(HOME)/.hyperdock
	cp -R install/* $(HOME)/.hyperdock

.PHONY: build
