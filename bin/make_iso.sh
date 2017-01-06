#!/bin/bash

. "config.sh"

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
	make
    fi

    # get gotty
    if [ ! -f $BUILD_DIR/gotty ]; then
        curl -sSL $GOTTY_URL/pre-release/gotty_linux_amd64.tar.gz | tar zx -C $BUILD_DIR
    fi
}

# copy kernel with needed modules
build_kernel() {
    # Build kernel
    cd ${BUILD_DIR}/linux

    if [ ! -f ${BUILD_DIR}/linux/vmlinux ]; then
       cp -f $PKG_DIR/kernel/config.x86_64 ${BUILD_DIR}/linux/.config
       cp -f $PKG_DIR/kernel/Makefile ${BUILD_DIR}/linux
       echo "${KERNELVERSION}" > ${BUILD_DIR}/linux/include/config/kernel.release
       export KERNELVERSION=${KERNELVERSION}

       make -j${THREADS} silentoldconfig
       make -j${THREADS} bzImage
       make -j${THREADS} modules
    fi

    # Install kernel
    mkdir -p /boot
    rm -rf /lib/modules/*
    make install
    make modules_install
}

# make initial fs layout
create_root() {
    rm -rf   $ROOT_DIR \
	     $ISO_DIR

    mkdir -p $BUILD_DIR \
	     $ROOT_DIR \
	     $DATA_DIR \
	     $ISO_DIR/boot

    # create base rootfs from alpine
    cp -f $PKG_DIR/mkinitfs/* /etc/mkinitfs/features.d/
    mkinitfs -F "ata base network virtio" -k -t $ROOT_DIR "$(ls /lib/modules)"
    cp -aR $SRC_DIR/rootfs/* $ROOT_DIR/
    cp -a /boot/config $ISO_DIR/boot
    cp -a /boot/vmlinuz $ISO_DIR/boot

    # install alpine base
    apk-install --initdb --root=$ROOT_DIR --allow-untrusted \
        alpine-baselayout \
	busybox \
	busybox-initscripts \
	busybox-suid \
	eudev \
	haveged \
	iptables \
	s6 \
	s6-dns \
	s6-rc \
	s6-linux-utils \
	s6-networking \
	s6-portable-utils

    cp -Rf /etc/terminfo/x /etc/terminfo/s $ROOT_DIR/etc/terminfo
    cp -f /usr/share/terminfo/x/xterm-color $ROOT_DIR/etc/terminfo/x
    cp -f /usr/share/terminfo/x/xterm-256color $ROOT_DIR/etc/terminfo/x
    cp -f /usr/share/terminfo/s/screen-256color $ROOT_DIR/etc/terminfo/s

    # setup os-release
    sed -i "s#{{VERSION}}#${VERSION}#g" $ROOT_DIR/etc/os-release
}

init_root() {
    # add users
    chroot $ROOT_DIR addgroup -S docker
    chroot $ROOT_DIR addgroup -S dnsmasq
    chroot $ROOT_DIR adduser -S -D -H -h /dev/null -s /sbin/nologin -G  docker docker
    chroot $ROOT_DIR adduser -S -D -H -h /dev/null -s /sbin/nologin -G  dnsmasq dnsmasq

    # copy config files
    cp -a $CONFIG_DIR/bashrc $ROOT_DIR/root/.bashrc
    cp -a $CONFIG_DIR/htoprc $ROOT_DIR/root/.htoprc
    cp -a $CONFIG_DIR/tmux.conf $ROOT_DIR/root/.tmux.conf
    cp -a $CONFIG_DIR/multitail.conf $ROOT_DIR/etc
    cp -a $CONFIG_DIR/session $ROOT_DIR/bin
    cp -Ra $PKG_DIR/s6 $ROOT_DIR/etc

    cp -Ra $PKG_DIR/tmuxifier $ROOT_DIR/usr/lib
    chroot $ROOT_DIR ln -s /usr/lib/tmuxifier/bin/tmuxifier /usr/bin/tmuxifier
    chmod 775 $ROOT_DIR/usr/lib/tmuxifier/layouts
    
    chroot $ROOT_DIR ln -s /etc/s6 /etc/s6-rc
    rm -rf $ROOT_DIR/var/run
    chroot $ROOT_DIR ln -s /run /var/run
}

install_env() {
    # provide initial environment
    echo -n "true" > $ROOT_DIR/etc/s6/env/DOCKER_RAMDISK
    echo -n "UTF-8" > $ROOT_DIR/etc/s6/env/CHARSET
    echo -n "UTF-8" > $ROOT_DIR/etc/s6/env/LC_ALL
    echo -n "UTF-8" > $ROOT_DIR/etc/s6/env/LC_CTYPE
    echo -n "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" > $ROOT_DIR/etc/s6/env/PATH
    echo -n "xterm-256color" > $ROOT_DIR/etc/s6/env/TERM
    echo -n "vi" > $ROOT_DIR/etc/s6/env/EDITOR
    echo -n "less" > $ROOT_DIR/etc/s6/env/PAGER
    echo -n "/usr/lib/tmuxifier" > $ROOT_DIR/etc/s6/env/TMUXIFIER
    echo -n "/usr/lib/tmuxifier/layouts" > $ROOT_DIR/etc/s6/env/TMUXIFIER_LAYOUT_PATH
    
    # write rng start seed
    dd if=/dev/random of=$ROOT_DIR/var/lib/seed count=1 bs=4096
}

install_pkg() {
    # install gotty
    #cp -a $BUILD_DIR/gotty $BIN_DIR

    # install unison
    cp -a $BUILD_DIR/unison/src/unison \
	  $BUILD_DIR/unison/src/unison-fsmonitor $BIN_DIR

    # install docker
    cp -a $BUILD_DIR/docker/* $BIN_DIR

    # Install portainer
    cp -f $PKG_DIR/portainer/images/logo.png $BUILD_DIR/portainer/images
    cp -Ra $BUILD_DIR/portainer $LIB_DIR
    mv $LIB_DIR/portainer/portainer $BIN_DIR

    # portainer db
    cp -a $PKG_DIR/portainer/portainer.db $DATA_DIR
}

clean_root() {
    cd $ROOT_DIR
    rm -rf usr/include var/cache/apk/* linuxrc etc/init.d etc/conf.d \
	   media .modloop srv etc/mkinitfs etc/*.apk-new etc/opt \
	   etc/sysctl.d etc/udhcpd.conf usr/local/share newroot etc/modules-load.d

    find $ROOT_DIR/etc -name "*-" | xargs rm -f
    find $ROOT_DIR -name "*.a" | xargs rm -f

    find $ROOT_DIR/usr/share -type d | grep -vE "share$|dhcpcd" | xargs rm -rf

    # strip binary files
    bash -c "find $ROOT_DIR -type f | grep -v modules | xargs strip --strip-all &>/dev/null; exit 0"
    chown -R root:root $ROOT_DIR
}

# Generate final iso image
make_iso() {

    # Pack rootfs
    cp -Ra $PKG_DIR/syslinux $ISO_DIR/boot/syslinux
    find | cpio -o -H newc | xz --check=crc32 -9 -e --verbose > $ISO_DIR/boot/initrd.img

    # Builds an image that can be used as an ISO and a disk image
    mkdir -p $SRC_DIR/dist
    xorriso -as mkisofs \
        -c boot/syslinux/boot.cat \
	-b boot/syslinux/isolinux.bin \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
	-eltorito-alt-boot \
	-e boot/initrd.img \
	-no-emul-boot -isohybrid-gpt-basdat \
	-o "$SRC_DIR/dist/iconlinux.iso" $ISO_DIR
}

log() {
    echo $'\e['"1;31m$(date "+%Y-%m-%d %H:%M:%S") [$(basename $0)] ${@}"$'\e[0m'
}

#################
## MAIN SCRIPT ##
#################

log "Downloading deps sources"  && download_deps
log "Building optimized kernel" && build_kernel
log "Creating new root"         && create_root
log "Initializing new root"     && init_root
log "Installing packages"       && install_pkg
log "Installing environment"    && install_env
log "Cleaning root"             && clean_root
log "Generating ISO image"      && make_iso
log "Finished succesfully"
