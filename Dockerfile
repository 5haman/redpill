FROM alpine:3.4
MAINTAINER Sergey Shyman

# Install builder packages
RUN echo "http://dl-5.alpinelinux.org/alpine/v3.5/main" > /etc/apk/repositories \
    && echo "http://dl-5.alpinelinux.org/alpine/v3.5/community" >> /etc/apk/repositories \
    && echo "http://dl-4.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk -U --no-cache add argp-standalone autoconf automake bash \
           bc binutils bison bsd-compat-headers busybox-initscripts \
           coreutils cpio curl emacs file flex g++ gcc git gmp-dev \
           go grep kbd kbd-misc linux-headers make mpc1-dev mpfr-dev \
           musl-dev ncurses ocaml perl protobuf-dev \
           sed squashfs-tools syslinux xorriso xz

#    && curl -sSL https://github.com/lalyos/docker-upx/releases/download/v3.91/upx \
#           -o /usr/bin/upx \
#    && chmod +x /usr/bin/upx \
#    && rm -f /usr/lib/libc.so

COPY bin/* /usr/bin/

ARG version
ARG buildroot
ARG buildcache
ARG debug
ARG KERNELVERSION

WORKDIR "${buildroot}"

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
