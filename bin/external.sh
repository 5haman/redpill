download_e2fs() {
    local pkgname=e2fsprogs
    local pkgver=1.43.3

    if [ ! -d $BUILD_DIR/$pkgname ]; then
        curl -sSL https://www.kernel.org/pub/linux/kernel/people/tytso/$pkgname/v$pkgver/$pkgname-$pkgver.tar.xz | tar Jx -C $BUILD_DIR
	mv $BUILD_DIR/$pkgname-$pkgver $BUILD_DIR/$pkgname

        cd $BUILD_DIR/$pkgname
        ./configure \
            --mandir=/usr/share/man \
            --disable-elf-shlibs \
	    --disable-tls \
	    --disable-nls

	make -j${THREADS} CFLAGS='-Os -pipe' LDFLAGS='-s -static'
    fi
}

download_dhcpcd() {
    local pkgname=dhcpcd
    local pkgver=6.11.5

    if [ ! -d $BUILD_DIR/$pkgname ]; then
	curl -sSL http://roy.marples.name/downloads/$pkgname/$pkgname-$pkgver.tar.xz | tar Jx -C $BUILD_DIR
	mv $BUILD_DIR/$pkgname-$pkgver $BUILD_DIR/$pkgname

        cd $BUILD_DIR/$pkgname
        ./configure \
	    --sysconfdir=/etc \
            --mandir=/usr/share/man \
            --localstatedir=/var \
            --libexecdir=/usr/lib/$pkgname \
            --dbdir=/var/lib/$pkgname

	make -j${THREADS} CFLAGS='-Os -pipe' LDFLAGS='-s -static'
    fi
}

download_deps() {
    # get kernel sources
    if [ ! -d $BUILD_DIR/linux ]; then
        cd $BUILD_DIR
        git clone -b pf-4.4 --depth 1 https://github.com/pfactum/pf-kernel
        mv ${BUILD_DIR}/pf-kernel ${BUILD_DIR}/linux
    fi

    # get docker
    if [ ! -d $BUILD_DIR/docker ]; then
        curl -sSL $DOCKER_URL/docker-$DOCKER_VERSION.tgz | tar xz -C $BUILD_DIR
    fi

    # get portainer
    if [ ! -d $BUILD_DIR/portainer ]; then
        curl -sSL $PORTAINER_URL/$PORTAINER_VERSION/portainer-$PORTAINER_VERSION-linux-amd64.tar.gz | tar xz -C $BUILD_DIR
    fi

    # get unison
    if [ ! -d $BUILD_DIR/unison ]; then
        curl -sSL $UNISON_URL/$UNISON_VERSION.tar.gz | tar zx -C $BUILD_DIR
        mv $BUILD_DIR/unison-$UNISON_VERSION $BUILD_DIR/unison
        cd $BUILD_DIR/unison
        sed -i -e "s/GLIBC_SUPPORT_INOTIFY 0/GLIBC_SUPPORT_INOTIFY 1/" src/fsmonitor/linux/inotify_stubs.c
        make -j${THREADS}
    fi

    # get gotty
    if [ ! -f $BUILD_DIR/gotty ]; then
        curl -sSL $GOTTY_URL/pre-release/gotty_linux_amd64.tar.gz | tar zx -C $BUILD_DIR
    fi

    # install python packages via pip
    if [ ! -d $BUILD_DIR/docker-registry-ui ]; then
        git clone --depth 1 https://github.com/ARKII/docker-registry-ui $BUILD_DIR/docker-registry-ui
    fi
    
    find $BUILD_DIR -name .git -type d | xargs rm -rf
}

download_s6() {
    if [ ! -d $BUILD_DIR/s6 ]; then
	git clone --depth 1 https://github.com/skarnet/skalibs $BUILD_DIR/s6/skalibs
	git clone --depth 1 https://github.com/skarnet/execline $BUILD_DIR/s6/execline
	git clone --depth 1 https://github.com/skarnet/s6 $BUILD_DIR/s6/s6
	git clone --depth 1 https://github.com/skarnet/s6-rc $BUILD_DIR/s6/s6-rc
	git clone --depth 1 https://github.com/skarnet/s6-linux-utils $BUILD_DIR/s6/s6-linux-utils
	git clone --depth 1 https://github.com/skarnet/s6-portable-utils $BUILD_DIR/s6/s6-portable-utils

	cd $BUILD_DIR/s6/skalibs
	./configure --disable-shared
	make -j${THREADS}
	make install

	cd $BUILD_DIR/s6/execline
        ./configure --enable-static-libc
        make -j${THREADS}
	make install

	cd $BUILD_DIR/s6/s6
        ./configure --enable-static-libc
        make -j${THREADS}
	make install

	cd $BUILD_DIR/s6/s6-linux-utils
	./configure --enable-static-libc
        make -j${THREADS}
	make install

	cd $BUILD_DIR/s6/s6-portable-utils
        ./configure --enable-static-libc
        make -j${THREADS}
	make install

        cd $BUILD_DIR/s6/s6-rc
        ./configure --enable-static-libc
        make -j${THREADS}
	make install
    fi

    find $BUILD_DIR -name .git -type d | xargs rm -rf
}
