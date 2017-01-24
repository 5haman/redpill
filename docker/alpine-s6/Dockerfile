FROM alpine:3.4
MAINTAINER Sergey Shyman

## Default shell params
ENV TERM=xterm-color \
    LANGUAGE=en_US:en \
    LANG=en_US.UTF-8 \
    LC_ALL=C.UTF-8

## Base filesystem
ADD rootfs/ /
ADD proxy.pem /tmp/proxy.pem

RUN apk-install \
	bash \
	binutils \
	ca-certificates \
	curl \
	dnsmasq \
    && mv /tmp/proxy.pem /usr/share/ca-certificates \
    && update-ca-certificates \
    && bash -c "strip --strip-all /usr/lib/* /usr/bin/*; exit 0" \
    && curl -k -sSL https://github.com/just-containers/s6-overlay/releases/download/v1.18.1.5/s6-overlay-amd64.tar.gz | tar xz -C / \
    && apk-remove binutils \
    && find / -name *.a | xargs rm -f \
    && rm -rf /usr/share/man/* \
	/usr/share/doc/* \
        /usr/include/* \
        /root/.cache \
        /tmp/*

ENTRYPOINT ["/init"]
