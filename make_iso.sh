#!/bin/bash

set -eu

BUILD_DIR="$SRC_DIR/build"
ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/initrd"
KERNEL_VERSION="4.4.39"
KERNEL_ID="grsec"
THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

get_deps() {
    # get kernel sources
    if [ ! -d $BUILD_DIR/linux ]; then
	#git clone -b pf-4.4 --depth 1 https://github.com/pfactum/pf-kernel ${BUILD_DIR}/linux
	curl -sSL http://ftp.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz | tar xJ -C ${BUILD_DIR}
	mv ${BUILD_DIR}/linux-${KERNEL_VERSION} ${BUILD_DIR}/linux
	curl -sSL -o ${BUILD_DIR}/linux/grsecurity.patch  http://dev.alpinelinux.org/~ncopa/grsec/grsecurity-3.1-${KERNEL_VERSION}-201604252206-alpine.patch
	cd ${BUILD_DIR}/linux
	patch -p1 -i grsecurity.patch
    fi
 
    # get docker
    if [ ! -d $BUILD_DIR/docker ]; then
        curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz | tar xz -C $BUILD_DIR
    fi

    if [ ! -d $BUILD_DIR/tcl/dev ]; then
	mkdir -p $BUILD_DIR/tcl
	cd $BUILD_DIR/tcl
        TCL_REPO_BASE=http://distro.ibiblio.org/tinycorelinux/7.x/x86_64
        curl -sSL $TCL_REPO_BASE/release/distribution_files/rootfs64.gz | gunzip | cpio -f -i -H newc -d --no-absolute-filenames
    fi
}

# copy kernel with needed modules
build_kernel() {
    cp -vf $SRC_DIR/kernel/config ${BUILD_DIR}/linux/.config

    # Build kernel
    cd ${BUILD_DIR}/linux
    #make -j${THREADS} oldconfig
    #make -j${THREADS} DISABLE_PAX_PLUGINS=y bzImage
    #make -j${THREADS} DISABLE_PAX_PLUGINS=y modules
    mkdir -p /boot
    rm -rf /lib/modules/*
    make install 
    make modules_install
}

# make initial fs layout
prepare_rootfs() {
    rm -rf $ROOT_DIR $ISO_DIR
    mkdir -p $BUILD_DIR $ROOT_DIR $ISO_DIR/boot

    # create base rootfs from alpine
    mkinitfs -F "base network virtio" -k -t $ROOT_DIR "$(ls /lib/modules)"
    cp -Rv $SRC_DIR/rootfs/* $ROOT_DIR/
    cp -v /boot/vmlinuz-$KERNEL_ID $ISO_DIR/boot/vmlinuz
    rm -rf $ROOT_DIR/dev
    cp -Rv $BUILD_DIR/tcl/dev $ROOT_DIR/dev
}

install_pkg() {
    # install alpine base
    echo "http://dl-5.alpinelinux.org/alpine/v3.5/main" > $ROOT_DIR/etc/apk/repositories
    echo "http://dl-5.alpinelinux.org/alpine/v3.5/community" >> $ROOT_DIR/etc/apk/repositories
    apk add --root=$ROOT_DIR -U --initdb --no-cache --allow-untrusted \
             alpine-baselayout busybox busybox-suid \
	     s6 s6-rc s6-linux-utils s6-portable-utils s6-networking \
	     bash iptables afpfs-ng tmux htop dnsmasq

    # Install vmware guest additions
    #cp -v /sbin/mount.vmhgfs $ROOT_DIR/sbin/mount.vmhgfs
    #cp -v /usr/sbin/mount.vmhgfs $ROOT_DIR/usr/sbin/mount.vmhgfs

    # install_docker
    cd $BUILD_DIR/docker
    #cp -v dockerd docker-containerd docker-containerd-shim docker-proxy $ROOT_DIR/usr/bin
}

clean_rootfs() {
    cd $ROOT_DIR
    rm -rf usr/include/* var/cache/apk/* linuxrc usr/share/* \
	   media newroot .modloop srv lib/libcrypt* etc/mkinitfs etc/*.apk-new

    echo "" > $ROOT_DIR/etc/motd

    bash -c "find $ROOT_DIR -type f | xargs strip --strip-all; exit 0"
}

# Generate final iso image
make_iso() {
    chroot $ROOT_DIR /etc/rc.update

    # Pack rootfs
    cp -Rv $SRC_DIR/syslinux $ISO_DIR/boot
    find | cpio -o -H newc | xz --check=none -9 -e --verbose > $ISO_DIR/boot/initrd.img

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
#log "Build s6 tools"         && build_s6
log "Install packages"       && install_pkg
log "Clean rootfs"           && clean_rootfs
log "Generate ISO image"     && make_iso

log "Finished succesfully"
