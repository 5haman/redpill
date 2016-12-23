#!/bin/bash

set -ex

ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/initrd"
THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

# make root filesystem base layout
prepare_rootfs() {
    mkdir -p $BUILD_DIR 
    mkdir -p $ROOT_DIR{/root,/etc/apk,/proc,/boot,/lib}

    #if [ ! -f $BUILD_DIR/tcrootfs.gz ]; then
    #    curl -o $BUILD_DIR/tcrootfs.gz -sSL http://distro.ibiblio.org/tinycorelinux/7.x/x86_64/release/distribution_files/rootfs64.gz
    #fi

    #mkdir -p /tmp/rootfs
    #cd /tmp/rootfs
    #zcat $BUILD_DIR/tcrootfs.gz | cpio -i -H newc -d 
    #mv dev $ROOT_DIR

    echo "http://dl-5.alpinelinux.org/alpine/v3.4/main" > $ROOT_DIR/etc/apk/repositories
    echo "http://dl-5.alpinelinux.org/alpine/v3.4/community" >> $ROOT_DIR/etc/apk/repositories
    apk add --root=$ROOT_DIR -U --initdb --no-cache --allow-untrusted \
            alpine-baselayout busybox busybox-suid \
	    musl musl-utils iptables libc-utils scanelf zlib

    cp -Rv /tmp/etc/* $ROOT_DIR/etc/

    mknod -m 666 $ROOT_DIR/dev/full c 1 7
    mknod -m 666 $ROOT_DIR/dev/ptmx c 5 2
    mknod -m 644 $ROOT_DIR/dev/random c 1 8
    mknod -m 644 $ROOT_DIR/dev/urandom c 1 9
    mknod -m 666 $ROOT_DIR/dev/zero c 1 5
    mknod -m 666 $ROOT_DIR/dev/tty c 5 0
    mknod -m 666 $ROOT_DIR/dev/console c 5 0

    # provide timezone info
    echo "UTC" > $ROOT_DIR/etc/timezone

    #/dev/sdXX /opt ext4 defaults,data=writeback,noatime,nodiratime 0 0
}

# copy kernel with needed modules
build_kernel() {
    if [ ! -d $BUILD_DIR/linux ]; then
	git clone -b pf-4.4 --depth 1 https://github.com/pfactum/pf-kernel ${BUILD_DIR}/linux
    fi
    cp -v /tmp/bin/kernel_config-virt ${BUILD_DIR}/linux/.config

    # Build linux kernel
    cd ${BUILD_DIR}/linux
    make -j${THREADS} oldconfig
    make -j${THREADS} bzImage
    make -j${THREADS} modules
}

install_kernel() {
    # Install kernel
    mkdir -p $ISO_DIR/boot
    cp -v ${BUILD_DIR}/linux/arch/x86_64/boot/bzImage $ISO_DIR/boot/vmlinuz
    
    # Install kernel modules
    cd ${BUILD_DIR}/linux
    make INSTALL_MOD_PATH=$ROOT_DIR modules_install
}

install_bootloader() {
    mkdir -p $ISO_DIR/boot/syslinux
    cp -Rv /tmp/syslinux $ISO_DIR/boot/syslinux
}

# Install vmware guest additions
install_virt() {
    #cp -v /sbin/mount.vmhgfs $ROOT_DIR/sbin/mount.vmhgfs
    cp -v /usr/sbin/mount.vmhgfs $ROOT_DIR/usr/sbin/mount.vmhgfs
}

install_docker() {
    if [ ! -d $BUILD_DIR/docker ]; then
        curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz | tar xz -C $BUILD_DIR
    fi
    cd $BUILD_DIR/docker
    cp -v dockerd docker-containerd docker-containerd-shim docker-proxy $ROOT_DIR/usr/bin
}

build_s6() {
    # build s6 skalibs
    if [ ! -d $BUILD_DIR/s6/skalibs ]; then
        git clone --depth 1 https://github.com/skarnet/skalibs $BUILD_DIR/s6/skalibs
    fi 
    cd $BUILD_DIR/s6/skalibs
    ./configure --disable-shared
    make -j${THREADS}
    make install

    # build s6 packages
    for PKG in execline s6 s6-linux-utils s6-portable-utils s6-rc; do
        if [ ! -d $BUILD_DIR/s6/$PKG ]; then
            git clone --depth 1 https://github.com/skarnet/$PKG $BUILD_DIR/s6/$PKG
        fi
        cd $BUILD_DIR/s6/$PKG
        ./configure --enable-static-libc
        make -j${THREADS}
	make install
    done
}

install_s6() {
    for PKG in execline s6 s6-linux-utils s6-portable-utils s6-rc; do
	cd $BUILD_DIR/s6/$PKG
        make DESTDIR=$ROOT_DIR install
    done

    cp -Rv /tmp/s6 $ROOT_DIR/etc/s6
    chroot "$ROOT_DIR" sh -c "/etc/s6/update && ln -s /etc/s6/init /init"
}

clean_rootfs() {
    cd $ROOT_DIR
    rm -rf usr/lib/* usr/include/* \
	   var/cache/apk/* linuxrc
}

make_config() {
    cat <<EOF > $ROOT_DIR/etc/inittab
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100
EOF
}

# Pack the rootfs
make_initrd() { 
    cd $ROOT_DIR

    #find | cpio -o -H newc | gzip -9 > $ISO_DIR/boot/initrd.img
    find | cpio -o -H newc | xz --check=crc32 -9 -e --verbose > $ISO_DIR/boot/initrd.img
}

# Pack the rootfs
make_iso() {
    # Builds an image that can be used as an ISO and a disk image
    xorriso  \
        -publisher "GPL2" -as mkisofs \
        -l -J -R -V "Hyperdock v${VERSION}" \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b boot/syslinux/isolinux.bin -c boot/syslinux/boot.cat \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -o "$BUILD_DIR/hyperdock.iso" $ISO_DIR 
}

echo_ansi() {
    local param=''
    if [[ "$1" == "-n" ]]; then param="$1"; shift
    elif [[ -z "$1" ]]; then shift; fi

    local code="$1"; shift
    if [[ -t 1 ]]; then echo $param $'\e['"${code}m$@"$'\e[0m';
    else echo $param "$@"; fi
}

log() {
    set +x
    echo_ansi '1;93' "==> $@" 1>&2
    set -x
}

#################
## MAIN SCRIPT ##
#################

rm -rf $ROOT_DIR $ISO_DIR

log "Prepare initrd dir"     && prepare_rootfs
#log "Build optimized kernel" && build_kernel
log "Install new kernel"     && install_kernel
log "Install VMWare drivers" && install_virt
#log "Install Docker engine " && install_docker
log "Build s6 tools"         && build_s6
log "Install s6"             && install_s6
log "Install bootloader"     && install_bootloader
#log "Prepare config files"   && make_config
log "Clean rootfs"           && clean_rootfs
log "Generate initrd image"  && make_initrd
log "Generate ISO image"     && make_iso
log "Finished succesfully"
