#!/bin/bash

set -eu

BUILD_DIR="$SRC_DIR/build"
ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/initrd"
KERNEL_VERSION="4.4.39"
KERNEL_ID="grsec"
PORTAINER_VERSION="1.11.0"

TCL_URL="http://distro.ibiblio.org/tinycorelinux/7.x/x86_64"
PORTAINER_URL="https://github.com/portainer/portainer/releases/download"

THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

get_deps() {
    # get kernel sources
    if [ ! -d $BUILD_DIR/linux ]; then
	curl -sSL http://ftp.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL_VERSION}.tar.xz | tar xJ -C ${BUILD_DIR}
	mv ${BUILD_DIR}/linux-${KERNEL_VERSION} ${BUILD_DIR}/linux
	curl -sSL -o ${BUILD_DIR}/linux/grsecurity.patch  http://dev.alpinelinux.org/~ncopa/grsec/grsecurity-3.1-${KERNEL_VERSION}-201604252206-alpine.patch
	cd ${BUILD_DIR}/linux
	patch -p1 -i grsecurity.patch
    fi
 
    # get docker
    if [ ! -d $BUILD_DIR/docker ]; then
        curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz | tar xz -C $BUILD_DIR
	strip --strip-all $BUILD_DIR/docker/*
    fi

    # get portainer
    if [ ! -d $BUILD_DIR/portainer ]; then
        curl -sSL $PORTAINER_URL/$PORTAINER_VERSION/portainer-$PORTAINER_VERSION-linux-amd64.tar.gz | tar xz -C $BUILD_DIR
	strip --strip-all $BUILD_DIR/portainer/portainer
    fi

    # get btsync
    #if [ ! -d $BUILD_DIR/btsync ]; then
	#mkdir -p $BUILD_DIR/btsync
	#cd $BUILD_DIR/btsync
	#curl -sSL https://download-cdn.resilio.com/stable/linux-x64/resilio-sync_x64.tar.gz | tar xz
	#mv rslsync btsync
	#strip --strip-all btsync
    #fi
}

# copy kernel with needed modules
build_kernel() {
    cp -f $SRC_DIR/config/kernel/config ${BUILD_DIR}/linux/.config

    # Build kernel
    cd ${BUILD_DIR}/linux
    if [ ! -f ${BUILD_DIR}/linux/vmlinux ]; then
        make -j${THREADS} silentoldconfig
        make -j${THREADS} DISABLE_PAX_PLUGINS=y bzImage
        make -j${THREADS} DISABLE_PAX_PLUGINS=y modules
    fi

    # Install kernel to build container
    mkdir -p /boot
    cp -R /lib/modules/*-grsec/misc /tmp
    rm -rf /lib/modules/*
    make install
    make modules_install
    #cp -R /lib/modules ${BUILD_DIR}
    cp -R /tmp/misc "/lib/modules/${KERNEL_VERSION}-${KERNEL_ID}/"
}

# make initial fs layout
prepare_rootfs() {
    rm -rf $ROOT_DIR $ISO_DIR
    mkdir -p $BUILD_DIR $ROOT_DIR $ISO_DIR/boot

    # create base rootfs from alpine
    cp -f $SRC_DIR/config/mkinitfs/* /etc/mkinitfs/features.d/
    mkinitfs -F "ata base network virtio" -k -t $ROOT_DIR "$(ls /lib/modules)"
    cp -aR $SRC_DIR/rootfs/* $ROOT_DIR/
    cp -a /boot/vmlinuz-$KERNEL_ID $ISO_DIR/boot/vmlinuz

    # recreate base device nodes
    rm -f $ROOT_DIR/dev/*
    mknod -m 666 $ROOT_DIR/dev/full c 1 7
    mknod -m 666 $ROOT_DIR/dev/ptmx c 5 2
    mknod -m 644 $ROOT_DIR/dev/random c 1 8
    mknod -m 644 $ROOT_DIR/dev/urandom c 1 9
    mknod -m 666 $ROOT_DIR/dev/zero c 1 5
    mknod -m 600 $ROOT_DIR/dev/console c 5 1
    mknod -m 666 $ROOT_DIR/dev/tty c 5 0
    mknod -m 666 $ROOT_DIR/dev/null c 1 3

    # setup os-release
    sed -i "s#{{VERSION}}#${VERSION}#g" $ROOT_DIR/etc/os-release
}

install_pkg() {
    # install alpine base
    apk-install --initdb --root=$ROOT_DIR --allow-untrusted \
        alpine-baselayout \
	busybox \
	busybox-initscripts \
	busybox-suid \
	iptables \
	s6 \
	s6-dns \
	s6-rc \
	s6-linux-init \
	s6-linux-utils \
	s6-portable-utils \
	s6-networking

    #apk-install --root="${ROOT_DIR}" \
	#        --allow-untrusted \
	#	$BUILD_DIR/btsync/glibc.apk \
	#    	$BUILD_DIR/btsync/glibc-bin.apk

    # add user for docker
    chroot $ROOT_DIR addgroup -S docker
    chroot $ROOT_DIR addgroup -S dnsmasq
    chroot $ROOT_DIR adduser -S -D -H -h /home/docker -s /sbin/nologin -G  docker docker
    chroot $ROOT_DIR adduser -S -D -H -h /dev/null -s /sbin/nologin -G  dnsmasq dnsmasq

    chroot $ROOT_DIR ln -s /usr/share/tmuxifier/bin/tmuxifier /usr/bin/tmuxifier

    # install docker
    cp -a $BUILD_DIR/docker/* $ROOT_DIR/usr/bin
 
    # install btsync
    #cp -a $BUILD_DIR/btsync/btsync $ROOT_DIR/usr/bin
 
    # Install portainer
    cp -Ra $BUILD_DIR/portainer $ROOT_DIR/usr/share/portainer
    cp -f $SRC_DIR/assets/logo.png $ROOT_DIR/usr/share/portainer/images
    cp -a $SRC_DIR/assets/portainer.db $ROOT_DIR/usr/share/portainer

    # get some random bits for vm rng init
    dd if=/dev/urandom of=$ROOT_DIR/root/.rnd bs=1 count=4096
    chmod 600 $ROOT_DIR/root/.rnd
}

clean_rootfs() {
    cd $ROOT_DIR
    rm -rf usr/include/* var/cache/apk/* linuxrc etc/init.d etc/conf.d \
	   media newroot .modloop srv etc/mkinitfs etc/*.apk-new etc/opt \
	   usr/local/share

    find $ROOT_DIR/etc -name "*-" | xargs rm -f

    find $ROOT_DIR/usr/share -type d | grep -vE "share$|dhcpcd|tmuxifier|portainer" | xargs rm -rf

    bash -c "find $ROOT_DIR -type f | grep -v modules | xargs strip --strip-all &>/dev/null; exit 0"
}

# Generate final iso image
make_iso() {

    # Pack rootfs
    cp -Ra $SRC_DIR/syslinux $ISO_DIR/boot
    find | cpio -o -H newc | xz --check=none -9 -e --verbose > $ISO_DIR/boot/initrd.img

    # Builds an image that can be used as an ISO and a disk image
    mkdir -p $SRC_DIR/dist
    xorriso  \
        -publisher "Hyperdock" -as mkisofs \
        -l -J -R -V "v${VERSION}" \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
	-c boot/syslinux/boot.cat \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -o "$SRC_DIR/dist/bootimage.iso" $ISO_DIR 
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
log "Install packages"       && install_pkg
log "Clean rootfs"           && clean_rootfs
log "Generate ISO image"     && make_iso

log "Finished succesfully"
