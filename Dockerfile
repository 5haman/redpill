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
	build-base binutils coreutils grep gcc git make go \
	cpio xorriso xz syslinux musl-dev linux-headers \
	perl sed installkernel gmp-dev bc mpfr-dev mpc1-dev \
	bash ca-certificates curl \
    && apk-install -X http://dl-4.alpinelinux.org/alpine/edge/testing \
	ocaml emacs

#	apk-tools bash ca-certificates curl rng-tools \
#        haveged dnsmasq kbd kbd-misc \
#        htop iptraf-ng tmux util-linux 

WORKDIR "${SRC_DIR}/bin"

ENTRYPOINT ["/bin/bash"]
