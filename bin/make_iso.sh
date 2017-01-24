#!/usr/bin/env bash

set -e; [ "$DEBUG" == "true" ] && set -x

buildroot=${BUILDDIR:-/opt/build}
buildcache=$buildroot/local/build

moddir=lib/modules/$KERNELVERSION
dist_image=$buildroot/dist/redpill_x86_64.img

log() {
    echo $'\e['"1;31m$(date "+%Y-%m-%d %H:%M:%S") [$(basename $0)] ${@}"$'\e[0m'
}

# manual copy of some binaries
host_install() {
    rsync -avr $buildroot/rootfs/ /rootfs/
    rsync -avr $buildroot/config/dotfiles/ /rootfs/root/
    cp $buildroot/bin/session /rootfs/bin/
    cp $buildroot/bin/diskmount /rootfs/sbin/
    cp $buildroot/bin/pill /rootfs/sbin/

    cat $buildroot/config/initfs/base.files | cpio -d -u -m -p /rootfs
}

pill_install() {
    # install libraries to builder container which required for static builds
    pill install linux skalibs execline s6 s6-linux-utils

    # install main packages for stage1
    pill -d /rootfs install execline s6 s6-portable-utils \
	s6-rc tmux-plugins #portainer #docker

    # install bootloader
    pill -d /iso install syslinux
}

chroot_install() {
    chroot /rootfs ln -sf /usr/share/tmuxifier/bin/tmuxifier /usr/bin/tmuxifier

    chroot /rootfs addgroup -S input
    #chroot /rootfs adduser -S -D -H -h /dev/null -s /sbin/nologin -G  docker docker
    #chroot /rootfs adduser -S -D -H -h /dev/null -s /sbin/nologin -G  dnsmasq dnsmasq

    install -m0664 -o root -g utmp /dev/null $rootfs/var/log/wtmp
    install -m0600 -o root -g utmp /dev/null $rootfs/var/log/lastlog
}
   
# create initrd image
create_image() {
    # strip binary files
    bash -c "find /rootfs -type f | xargs strip --strip-all &>/dev/null; exit 0"

    rm -rf /rootfs/usr/include /rootfs/etc/s6/inactive

    # copy kernel modules
    cd "/$moddir"
    mkdir -p "/rootfs/$moddir"
   (cat $buildroot/config/initfs/base.modules | cpio -d -u -m -p "/rootfs/$moddir") &>/dev/null

    depmod -b "/rootfs" $KERNELVERSION &>/dev/null

    # setup os-release
    sed -i "s#{{VERSION}}#${version}#g" /rootfs/etc/os-release
    echo "${version}" > /rootfs/etc/version

    # create initrd image
    cd /rootfs
    umask 0022
   (chown -R root:root /rootfs && cd /rootfs && find . | sort | cpio --quiet -o -H newc | xz --check=crc32 -9 -e --verbose) > /iso/ramdisk.img
}

make_iso() {
    # install kernel
    cp /boot/vmlinuz /iso/kernel

    # Builds an image that can be used as an ISO and a disk image
    xorriso -as mkisofs \
            -c syslinux/boot.cat \
            -b syslinux/isolinux.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
            -eltorito-alt-boot \
            -e /ramdisk.img \
            -no-emul-boot -isohybrid-gpt-basdat \
            -o $dist_image /iso
}

# main script
log "Installing packages"
pill_install
host_install
chroot_install

log "Compressing initrd"
create_image

log "Making final image"
make_iso
