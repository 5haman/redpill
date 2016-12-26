NAME	  = bastion/hyperdock-build
TAG	  = latest
VERSION   = 0.1
FULLNAME  = $(NAME):$(TAG)
SRC_DIR   = /usr/src

default: build run

build:
	docker  build \
		--build-arg SRC_DIR=$(SRC_DIR) \
		--build-arg VERSION=$(VERSION) \
		-t $(FULLNAME) .

run:
	mkdir -p build
	docker run -it --rm \
		-v $(PWD):$(SRC_DIR) \
		$(FULLNAME)
	ls -la hyperdock.iso

push:
	docker tag $(FULLNAME) $(FULLNAME)
	docker push $(FULLNAME)

.PHONY: build
