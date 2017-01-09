FROM alpine:3.4

ARG VERSION
ARG SRC_DIR
ARG DOCKER_VERSION

ENV VERSION ${VERSION:-1.0}
ENV SRC_DIR ${SRC_DIR:-/usr/src}
ENV DOCKER_VERSION ${DOCKER_VERSION:-1.12.5}

ADD rootfs/etc/apk/repositories /etc/apk/repositories
ADD rootfs/usr/bin/ /usr/bin/

# Install packages for build container
RUN apk-install -t .build-deps \
	build-base binutils coreutils grep gcc git make \
	cpio mkinitfs xorriso musl-dev xz syslinux musl-dev linux-headers \
	perl sed installkernel gmp-dev bc mpfr-dev mpc1-dev \
    && apk-install -X http://dl-4.alpinelinux.org/alpine/edge/testing \
	ocaml emacs

# Install packages for rootfs
RUN apk-install \
	apk-tools bash ca-certificates coreutils curl dhcpcd rsync rng-tools \
        haveged dropbear dropbear-ssh dropbear-scp dnsmasq kbd kbd-misc e2fsprogs \
        htop iptraf-ng multitail ncurses-terminfo python3 tmux util-linux squashfs-tools

WORKDIR "${SRC_DIR}/bin"

ENTRYPOINT ["/bin/bash"]
