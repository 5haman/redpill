FROM bastion/alpine-s6:latest

ENV NODE_VERSION=v4.4.7
    
WORKDIR /usr/src
RUN CONFIG_FLAGS="--fully-static --shared-zlib --shared-libuv --shared-openssl" \
    && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
    && apk-install -t .build-deps build-base make gcc g++ paxctl libgcc libstdc++ \
	openssl-dev zlib-dev libuv-dev python linux-headers binutils-gold python-dev \
    && curl -sSL https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}.tar.gz | tar xz \
    && cd node-${NODE_VERSION} \
    && ./configure --prefix=/usr ${CONFIG_FLAGS} \
    && make -j${NPROC} -C out mksnapshot BUILDTYPE=Release \
    && paxctl -cm out/Release/mksnapshot \
    && make -j${NPROC} \
    && make install \
    && strip --strip-all /usr/bin/node \
    && paxctl -cm /usr/bin/node \
    && npm install -g pnpm \
    && pnpm install -g log.io \
    && find /usr/lib/node_modules/ -type d |grep -E "/test|/man|/doc|/example|/benchmark" | xargs rm -rf \
    && find /usr/lib/node_modules/ -type f | grep -vE "\.js|\.map|\.ts|\.tap|\.ls|\.xml|\/bin|\/gyp\/pylib|cb2promise" | xargs rm -f \
    &&  bash -c "find / -type f | xargs strip --strip-all &>/dev/null; exit 0" \
    && apk-remove .build-deps \
    && cd / \
    && rm -rf /usr/src/* /usr/share/doc \
        /usr/share/man /tmp/* \
        /var/cache/apk/* /root/.n* /root/.cache \
        /usr/lib/node_modules/npm/html \
	/usr/include
