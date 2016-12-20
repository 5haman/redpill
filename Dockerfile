FROM alpine:3.4

ARG BUILD_DIR
ARG DOCKER_VERSION
ARG LINUX_VERSION

ENV BUILD_DIR ${BUILD_DIR:-/build}
ENV DOCKER_VERSION ${DOCKER_VERSION:-1.12.5}
ENV LINUX_VERSION ${LINUX_VERSION:-4.4.30-0-grsec}

COPY bin/* /tmp/
COPY syslinux /tmp/

WORKDIR /tmp

RUN apk -U --no-cache add -t .build-deps \
	bash binutils grep gcc coreutils curl git make \
	xorriso open-vm-tools open-vm-tools-grsec \
	mkinitfs syslinux xz musl-dev linux-headers

VOLUME "${BUILD_DIR}"

ENTRYPOINT ["/tmp/make_iso.sh"]
