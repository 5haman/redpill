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

    # get Tiny Core linux rootfs for /dev
    if [ ! -d $BUILD_DIR/tcl/dev ]; then
	mkdir -p $BUILD_DIR/tcl
	cd $BUILD_DIR/tcl
        TCL_REPO_BASE=http://distro.ibiblio.org/tinycorelinux/7.x/x86_64
        curl -sSL $TCL_REPO_BASE/release/distribution_files/rootfs64.gz | gunzip | cpio -f -i -H newc -d --no-absolute-filenames
    fi
}

# copy kernel with needed modules
build_kernel() {
    cp -f $SRC_DIR/config/kernel_config ${BUILD_DIR}/linux/.config

    # Build kernel
    cd ${BUILD_DIR}/linux
    #make -j${THREADS} silentoldconfig
    #make -j${THREADS} DISABLE_PAX_PLUGINS=y bzImage
    #make -j${THREADS} DISABLE_PAX_PLUGINS=y modules
    mkdir -p /boot
    rm -rf /lib/modules/*
    make install 
    make modules_install
    rm -rf $BUILD_DIR/modules
    cp -R /lib/modules $BUILD_DIR/modules
}

# make initial fs layout
prepare_rootfs() {
    rm -rf $ROOT_DIR $ISO_DIR
    mkdir -p $BUILD_DIR $ROOT_DIR $ISO_DIR/boot

    # create base rootfs from alpine
    cp -f $SRC_DIR/config/network.files /etc/mkinitfs/features.d/network.files
    cp -f $SRC_DIR/config/network.modules /etc/mkinitfs/features.d/network.modules
    mkinitfs -F "base network virtio xfs" -k -t $ROOT_DIR "$(ls /lib/modules)"
    cp -aR $SRC_DIR/rootfs/* $ROOT_DIR/
    cp -a /boot/vmlinuz-$KERNEL_ID $ISO_DIR/boot/vmlinuz
    rm -rf $ROOT_DIR/dev
    cp -Ra $BUILD_DIR/tcl/dev $ROOT_DIR/dev
}

install_pkg() {
    # install alpine base
    apk add --root=$ROOT_DIR -U --initdb --no-cache --allow-untrusted \
        alpine-baselayout \
	apk-tools \
	bash \
	busybox \
	busybox-suid \
	dhcpcd \
	dropbear \
	dropbear-ssh \
	dropbear-scp \
	dnsmasq \
	htop \
	iptables \
	s6 \
	s6-rc \
	s6-linux-utils \
	s6-portable-utils \
	s6-networking \
	tmux

    # add user for docker
    chroot $ROOT_DIR addgroup -S docker
    chroot $ROOT_DIR adduser -s /usr/bin/autologin -S -G docker docker

    # install_docker
    cd $BUILD_DIR/docker
    #cp -a dockerd docker-containerd docker-containerd-shim docker-proxy $ROOT_DIR/usr/bin
 
    # prepare s6-rc compiled services
    chroot $ROOT_DIR /etc/rc.update
}

clean_rootfs() {
    cd $ROOT_DIR
    rm -rf usr/share/* usr/include/* var/cache/apk/* linuxrc usr/lib/libcrypt* \
	   media newroot .modloop srv lib/libcrypt* etc/mkinitfs etc/*.apk-new \
	   etc/init.d

    bash -c "find $ROOT_DIR -type f | grep -v modules | xargs strip --strip-all &>/dev/null; exit 0"
}

# Generate final iso image
make_iso() {

    # Pack rootfs
    cp -Ra $SRC_DIR/syslinux $ISO_DIR/boot
    find | cpio -o -H newc | xz --check=none -9 -e --verbose > $ISO_DIR/boot/initrd.img

    # Builds an image that can be used as an ISO and a disk image
    mkdir -p $SRC_DIR/install
    xorriso  \
        -publisher "GPL2" -as mkisofs \
        -l -J -R -V "Hyperdock v${VERSION}" \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin \
	-c boot/syslinux/boot.cat \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -o "$SRC_DIR/install/bootimage.iso" $ISO_DIR 
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
