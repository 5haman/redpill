FROM alpine:3.4

ARG VERSION
ARG SRC_DIR
ARG DOCKER_VERSION

ENV VERSION ${VERSION:-0.1}
ENV SRC_DIR ${SRC_DIR:-/usr/src}
ENV DOCKER_VERSION ${DOCKER_VERSION:-1.12.5}

RUN echo "http://dl-5.alpinelinux.org/alpine/v3.5/main" > $ROOT_DIR/etc/apk/repositories \
    && echo "http://dl-5.alpinelinux.org/alpine/v3.5/community" >> $ROOT_DIR/etc/apk/repositories \
    && apk -U --no-cache add -t .build-deps \
	bash binutils grep gcc curl git make cpio \
	mkinitfs xorriso musl-dev xz syslinux \
	perl sed installkernel gmp-dev bc \
	mpfr-dev mpc1-dev open-vm-tools

WORKDIR "${SRC_DIR}"

VOLUME "${SRC_DIR}"

ENTRYPOINT ["./make_iso.sh"]
