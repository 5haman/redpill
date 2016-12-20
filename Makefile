NAME	  = bastion/litevm
TAG	  = latest
FULLNAME  = $(NAME):$(TAG)
BUILD_DIR = /build

default: build iso

build:
	docker  build \
		--build-arg BUILD_DIR=$(BUILD_DIR) \
		-t $(FULLNAME) .

iso:
	rm -rf build/*
	docker run -it --rm \
		-v $(PWD)/build:$(BUILD_DIR) \
		$(FULLNAME)
	mv build/litevm.iso .
	ls -la litevm.iso

push:
	docker tag $(FULLNAME) $(FULLNAME)
	docker push $(FULLNAME)

.PHONY: build iso
