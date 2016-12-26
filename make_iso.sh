#!/bin/bash

set -eu

BUILD_DIR="$SRC_DIR/build"
ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/initrd"
KERNEL_ID="hyper+"
THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

get_deps() {
    # get kernel sources
    if [ ! -d $BUILD_DIR/linux ]; then
	git clone -b pf-4.4 --depth 1 https://github.com/pfactum/pf-kernel ${BUILD_DIR}/linux
    fi

    # get s6 libs
    if [ ! -d $BUILD_DIR/s6/skalibs ]; then
        git clone --depth 1 https://github.com/skarnet/skalibs $BUILD_DIR/s6/skalibs
    fi 

    # get s6 utils
    for PKG in execline s6 s6-linux-utils s6-portable-utils s6-rc; do
        if [ ! -d $BUILD_DIR/s6/$PKG ]; then
            git clone --depth 1 https://github.com/skarnet/$PKG $BUILD_DIR/s6/$PKG
        fi
    done 
}

# copy kernel with needed modules
build_kernel() {
    cp -vf $SRC_DIR/kernel/config ${BUILD_DIR}/linux/.config
    cp -vf $SRC_DIR/kernel/Makefile ${BUILD_DIR}/linux/Makefile

    # Build kernel
    cd ${BUILD_DIR}/linux
    make -j${THREADS} oldconfig
    make -j${THREADS} bzImage
    mkdir -p /boot
    make install
}

build_s6() {
    # build s6 libs
    cd $BUILD_DIR/s6/skalibs
    ./configure --disable-shared
    make -j${THREADS}
    make install

    # build s6 utils
    for PKG in execline s6 s6-linux-utils s6-portable-utils s6-rc; do
        cd $BUILD_DIR/s6/$PKG
        ./configure --enable-static-libc
        make -j${THREADS}
	make install
    done
}

# make initial fs layout
prepare_rootfs() {
    rm -rf $ROOT_DIR $ISO_DIR
    mkdir -p $BUILD_DIR $ROOT_DIR $ISO_DIR/boot

    # create base rootfs from alpine
    mkinitfs -F "base" -k -t $ROOT_DIR "$(ls /lib/modules)"
    rm -rf $ROOT_DIR/lib/modules/*

    cp -v /boot/vmlinuz-$KERNEL_ID $ISO_DIR/boot/vmlinuz
    cp -Rv $SRC_DIR/rootfs/* $ROOT_DIR/
}

install_pkg() {
    # install alpine base
    echo "http://dl-5.alpinelinux.org/alpine/v3.5/main" > $ROOT_DIR/etc/apk/repositories
    echo "http://dl-5.alpinelinux.org/alpine/v3.5/community" >> $ROOT_DIR/etc/apk/repositories
    apk add --root=$ROOT_DIR -U --initdb --no-cache --allow-untrusted \
             alpine-baselayout busybox busybox-suid iptables afpfs-ng

    # install_s6
    for PKG in execline s6 s6-linux-utils s6-portable-utils s6-rc; do
	cd $BUILD_DIR/s6/$PKG
        make DESTDIR=$ROOT_DIR install
    done

    # Install vmware guest additions
    #cp -v /sbin/mount.vmhgfs $ROOT_DIR/sbin/mount.vmhgfs
    #cp -v /usr/sbin/mount.vmhgfs $ROOT_DIR/usr/sbin/mount.vmhgfs

    # install_docker
    if [ ! -d $BUILD_DIR/docker ]; then
        curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz | tar xz -C $BUILD_DIR
    fi
    cd $BUILD_DIR/docker
    cp -v dockerd docker-containerd docker-containerd-shim docker-proxy $ROOT_DIR/usr/bin
}

clean_rootfs() {
    cd $ROOT_DIR
    rm -rf usr/lib/s6* usr/lib/execline usr/include/* \
	   var/cache/apk/* linuxrc usr/share/terminfo/* \
	   media newroot usr/lib/xtables sbin/xtables-*

    echo "" > $ROOT_DIR/etc/motd

    bash -c "find $ROOT_DIR -type f | xargs strip --strip-all; exit 0"
}

# Generate final iso image
make_iso() {
    #chroot $ROOT_DIR /etc/rc/update

    # Pack rootfs
    cp -Rv $SRC_DIR/syslinux $ISO_DIR/boot
    find | cpio -o -H newc | xz --check=none -6 --verbose > $ISO_DIR/boot/initrd.img
    #find | cpio -o -H newc | xz --check=none -9 -e --verbose > $ISO_DIR/boot/initrd.img

    # Builds an image that can be used as an ISO and a disk image
    xorriso  \
        -publisher "GPL2" -as mkisofs \
        -l -J -R -V "Hyperdock v${VERSION}" \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
	-c boot/syslinux/boot.cat \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -o "$SRC_DIR/hyperdock.iso" $ISO_DIR 
}

log() {
    echo $'\e['"1;31m$(date "+%Y-%m-%d %H:%M:%S") [$(basename $0)] ${@}"$'\e[0m'
}

#################
## MAIN SCRIPT ##
#################

log "Get deps sources"       && get_deps
log "Build optimized kernel" && build_kernel
log "Prepare initrd dir"     && prepare_rootfs
log "Build s6 tools"         && build_s6
log "Install packages"       && install_pkg
log "Clean rootfs"           && clean_rootfs
log "Generate ISO image"     && make_iso

log "Finished succesfully"
