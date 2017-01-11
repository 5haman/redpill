FROM alpine:3.4

ARG VERSION
ARG SRC_DIR
ARG DOCKER_VERSION

ENV VERSION ${VERSION:-0.2}
ENV SRC_DIR ${SRC_DIR:-/usr/src}

ADD src/rootfs/etc/apk/repositories /etc/apk/repositories
ADD src/rootfs/usr/bin/ /usr/bin/

# Install packages for build container
RUN apk-install -t .build-deps \
	gcc musl-dev linux-headers bash file curl bsd-compat-headers \
	autoconf automake protobuf-dev zlib-dev libressl-dev g++ \
	binutils coreutils grep gcc git make go bison flex \
	cpio xorriso xz syslinux musl-dev linux-headers ncurses \
	perl sed installkernel gmp-dev bc mpfr-dev mpc1-dev \
    && apk-install -X http://dl-4.alpinelinux.org/alpine/edge/testing \
	ocaml emacs

COPY bin/* /usr/bin/

WORKDIR "${SRC_DIR}"

ENTRYPOINT ["/bin/bash"]
