FROM alpine:edge
MAINTAINER Sergey Shyman

ENV GOPATH=/opt/build/local/go \
    PATH=$GOPATH/bin:$PATH \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Install builder packages
RUN apk -U update \
    && apk -U upgrade \
    && apk -U --no-cache add bash \
           binutils busybox-initscripts rsync cpio \
           bc coreutils curl file g++ gcc git xz \
           go grep linux-headers make patch sed syslinux \
           musl-dev ncurses perl tar xorriso

ARG version
ARG DEBUG
ARG BUILDDIR
ARG KERNELVERSION

ADD bin/entrypoint.sh /
ADD bin/pill /sbin

WORKDIR "$BUILDDIR"

ENTRYPOINT ["/entrypoint.sh"]
