FROM alpine:3.4

ARG VERSION
ARG SRC_DIR
ARG DOCKER_VERSION

ENV VERSION ${VERSION:-0.1}
ENV SRC_DIR ${SRC_DIR:-/usr/src}
ENV DOCKER_VERSION ${DOCKER_VERSION:-1.12.5}

ADD rootfs/etc/apk/repositories /etc/apk/repositories
ADD rootfs/usr/bin/ /usr/bin/

RUN apk-install -t .build-deps \
	bash binutils grep gcc curl git make cpio \
	mkinitfs xorriso musl-dev xz syslinux \
	perl sed installkernel gmp-dev bc mpfr-dev mpc1-dev \
	open-vm-tools open-vm-tools-grsec

WORKDIR "${SRC_DIR}"

ENTRYPOINT ["./make_iso.sh"]
