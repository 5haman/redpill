FROM alpine:3.4

ARG BUILD_DIR
ARG DOCKER_VERSION

ENV BUILD_DIR ${BUILD_DIR:-/build}
ENV DOCKER_VERSION ${DOCKER_VERSION:-1.12.5}

WORKDIR "${BUILD_DIR}"

RUN apk -U --no-cache add -t .build-deps \
	bash binutils grep gcc coreutils curl git make \
	xorriso open-vm-tools open-vm-tools-grsec \
	mkinitfs syslinux xz musl-dev linux-headers \
	perl bc file

ARG VERSION
ENV VERSION VERSION

#COPY bin /tmp/bin
#COPY syslinux /tmp/syslinux
#COPY etc /tmp/etc

VOLUME "${BUILD_DIR}"

ENTRYPOINT ["/usr/src/bin/make_iso.sh"]
#ENTRYPOINT ["bash"]
