#!/bin/bash


ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/rootfs"
THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

# make root filesystem base layout
prepare_rootfs() {
    log "Preparing root directory"
    rm -rf $BUILD_DIR/* 
    mkdir -p $ROOT_DIR $BUILD_DIR/boot
    mkdir -p $ROOT_DIR{/root,/etc/apk,/proc,/dev,/boot}
    echo "http://dl-5.alpinelinux.org/alpine/v3.4/main" > $ROOT_DIR/etc/apk/repositories
    echo "http://dl-5.alpinelinux.org/alpine/v3.4/community" >> $ROOT_DIR/etc/apk/repositories
    apk add --root=$ROOT_DIR -U --initdb --allow-untrusted \
            alpine-baselayout busybox busybox-suid musl musl-utils \
            iptables libc-utils scanelf zlib

    # provide timezone info
    echo "UTC" > $ROOT_DIR/etc/timezone

    #echo -e "/dev/sda1 none swap  sw                0 0" >> $ROOT_DIR/etc/fstab
    #echo -e "/dev/sda2 /    ext4  defaults,noatime,nodiratime 1 1" >> $ROOT_DIR/etc/fstab
}

# copy kernel with needed modules
install_kernel() {
    log "Installing new kernel"

    for dir in `cat $BUILD_DIR/bin/kernel_mod`; do
        destdir=`dirname "/lib/modules/${LINUX_VERSION}/${dir}"`
        mkdir -p "${ROOT_DIR}${destdir}"
        cp -avR "/lib/modules/${LINUX_VERSION}/${dir}" "${ROOT_DIR}${destdir}"
    done

    mkdir -p $ISO_DIR
    cp -av /boot/System.map-grsec $ISO_DIR
    cp -av /boot/vmlinuz-grsec $ISO_DIR
    cp -av /tmp/boot.cat $ISO_DIR
    cp -av /tmp/syslinux.bin $ISO_DIR
}

# Install vmware guest additions
install_vmware() {
    log "Installing vmware guest additions"
    cp -av /sbin/mount.vmhgfs $ROOT_DIR/sbin/mount.vmhgfs
    cp -av /usr/sbin/mount.vmhgfs $ROOT_DIR/usr/sbin/mount.vmhgfs
}

install_docker() {
    cd $BUILD_DIR
    log "Installing Docker"
    curl -sSL https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz | tar xz
    cd docker
    mv dockerd docker-containerd docker-containerd-shim docker-proxy $ROOT_DIR/usr/bin
}

build_s6() {
    log "Building s6"
    cd $BUILD_DIR

    # skalibs
    rm -rf $BUILD_DIR/skalibs
    git clone --depth 1 https://github.com/skarnet/skalibs $BUILD_DIR/skalibs
    cd $BUILD_DIR/skalibs
    ./configure --disable-shared
    make -j${THREADS}
    make install

    # execline
    rm -rf $BUILD_DIR/execline
    git clone --depth 1 https://github.com/skarnet/execline $BUILD_DIR/execline
    cd $BUILD_DIR/execline
    ./configure --enable-static-libc
    make -j${THREADS}
    make install
    make DESTDIR=$ROOT_DIR install

    # s6
    rm -rf $BUILD_DIR/s6
    git clone --depth 1 https://github.com/skarnet/s6 $BUILD_DIR/s6
    cd $BUILD_DIR/s6
    ./configure --enable-static-libc
    make -j${THREADS}
    make install
    make DESTDIR=$ROOT_DIR install

    # s6-linux-utils
    rm -rf $BUILD_DIR/s6-linux-utils
    git clone --depth 1 https://github.com/skarnet/s6-linux-utils $BUILD_DIR/s6-linux-utils
    cd $BUILD_DIR/s6-linux-utils
    ./configure --enable-static-libc
    make -j${THREADS}
    make DESTDIR=$ROOT_DIR install

    # s6-portable-utils
    rm -rf $BUILD_DIR/s6-portable-utils
    git clone --depth 1 https://github.com/skarnet/s6-portable-utils $BUILD_DIR/s6-portable-utils
    cd $BUILD_DIR/s6-portable-utils
    ./configure --enable-static-libc
    make -j${THREADS}
    make DESTDIR=$ROOT_DIR install

    # s6-linux-init
    rm -rf $BUILD_DIR/s6-linux-init
    git clone --depth 1 https://github.com/skarnet/s6-linux-init $BUILD_DIR/s6-linux-init
    cd $BUILD_DIR/s6-linux-init
    ./configure --enable-static-libc
    make -j${THREADS}
}

install_s6() {
    log "Installing s6"

    cd $BUILD_DIR/s6-linux-init
    ./s6-linux-init-maker -p "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" -d 1 "$ROOT_DIR/etc/s6-init"

    mv s6-halt s6-poweroff s6-reboot $ROOT_DIR/sbin
    rm -f $ROOT_DIR/sbin/halt $ROOT_DIR/sbin/poweroff $ROOT_DIR/sbin/reboot

    cd $ROOT_DIR/sbin
    ln -sf s6-halt halt
    ln -sf s6-poweroff poweroff
    ln -sf s6-reboot reboot
}

install_meta() {
    cat > $ROOT_DIR/etc/os-release <<-EOF
NAME=LiteVM
VERSION=0.2
ID=litevm
ID_LIKE=lvm
VERSION_ID=0.2
PRETTY_NAME="LiteVM (version 0.2)"
ANSI_COLOR="1;34"
HOME_URL="https://github.com/5haman/litevm"
BUG_REPORT_URL="https://github.com/5haman/litevm/issues"
EOF
}

cleanup() {
    log "Cleaning up"
    rm -rf $ROOT_DIR/usr/lib
    rm -rf $ROOT_DIR/usr/include
    rm -rf $ROOT_DIR/var/cache/apk/*
    rm -rf $ROOT_DIR/media
    rm -rf $ROOT_DIR/srv
    rm -rf $BUILD_DIR/s6* $BUILD_DIR/execline
}

# Pack the rootfs
make_initrd() {
    cd $ROOT_DIR
    log "Generating initrd image"
    find | ( set -x; cpio -o -H newc | xz -9 --format=lzma --verbose --verbose ) > $ISO_DIR/initrd.img
}

# Pack the rootfs
make_iso() {
    cd $ROOT_DIR

    # Builds an image that can be used as an ISO and a disk image
    xorriso  \
        -publisher "LiteVM" -as mkisofs \
        -l -J -R -V "LiteVM-v0.2" \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -b syslinux.bin -c boot.cat \
        -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
        -o "$BUILD_DIR/litevm.iso" $ISO_DIR 
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
    echo_ansi '1;93' "==> $@" 1>&2
}

# main script
prepare_rootfs
install_kernel
install_vmware
install_docker
build_s6
install_s6
install_meta
cleanup
make_initrd
make_iso
