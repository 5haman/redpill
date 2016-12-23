NAME	  = bastion/hyperdock-build
TAG	  = latest
VERSION   = 0.1
FULLNAME  = $(NAME):$(TAG)
BUILD_DIR = /usr/src

default: build run

build:
	docker  build \
		--build-arg BUILD_DIR=$(BUILD_DIR) \
		--build-arg VERSION=$(VERSION) \
		-t $(FULLNAME) .

run:
	#rm -rf build/*
	docker run -it --rm \
		-v $(PWD):$(BUILD_DIR) \
		$(FULLNAME)
	mv build/hyperdock.iso .
	ls -la hyperdock.iso

push:
	docker tag $(FULLNAME) $(FULLNAME)
	docker push $(FULLNAME)

.PHONY: build
