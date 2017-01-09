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

install_static() {
    # execline
    cd $BUILD_DIR/s6/skalibs
    make install

    # execline
    cd $BUILD_DIR/s6/execline
    make install
    make DESTDIR=$INITRD_DIR install

    # s6
    cd $BUILD_DIR/s6/s6
    make DESTDIR=$INITRD_DIR install

    # s6-linux-utils
    cd $BUILD_DIR/s6/s6-linux-utils
    make DESTDIR=$INITRD_DIR install

    # s6-portable-utils
    cd $BUILD_DIR/s6/s6-portable-utils
    make DESTDIR=$INITRD_DIR install

    cd $BUILD_DIR/s6/s6-rc
    make DESTDIR=$INITRD_DIR install

    cd $BUILD_DIR/dhcpcd
    make DESTDIR=$INITRD_DIR install

    cd $BUILD_DIR/e2fsprogs
    make install
    cp /sbin/mkfs.ext2 $INITRD_DIR/sbin
}

# make initial fs layout
create_initrd() {
    mkdir -p $INITRD_DIR $ISO_DIR
    rm -rf   $INITRD_DIR/* $ISO_DIR/*

    # create base rootfs
    #cp -f $PKG_DIR/mkinitfs/* /etc/mkinitfs/features.d/
    #mkinitfs -F "base" -k -t $INITRD_DIR "$(ls /lib/modules)"

    cp -aR $SRC_DIR/rootfs/* $INITRD_DIR/

    for mod in $(cat pkg/mkinitfs/base.modules | tr "\n" " "); do
	file="$(find /lib/modules -name $(basename $mod))"
	dir="$(dirname $file)"
	mkdir -p $INITRD_DIR/$dir
	cp -Rv $file $INITRD_DIR/$file
    done

    # install alpine base
    apk-install --initdb --root=$INITRD_DIR --allow-untrusted \
	busybox-static

    # setup os-release
    sed -i "s#{{VERSION}}#${VERSION}#g" $INITRD_DIR/etc/os-release

    chroot $INITRD_DIR /bin/busybox.static --install -s
    chroot $INITRD_DIR sh -c \
	"mkdir -p /usr/bin /usr/sbin /proc /sys /dev /tmp /run/s6 /var/log;
    	 ln -s /bin/busybox.static /bin/busybox;
         passwd root -d toor"

    # install kernel modules
    moddir="/lib/modules/$(ls /lib/modules)"
    cd $moddir
    cat $PKG_DIR/mkinitfs/base.modules | cpio -d -u -m -p "$INITRD_DIR/$moddir"

    install -m0664 -o root -g utmp /dev/null $INITRD_DIR/run/utmp
    install -m0664 -o root -g utmp /dev/null $INITRD_DIR/var/log/wtmp
    install -m0600 -o root -g utmp /dev/null $INITRD_DIR/var/log/lastlog

    # copy config files
    cp -a $CONFIG_DIR/session $INITRD_DIR/bin
    cp -Ra $PKG_DIR/s6 $INITRD_DIR/etc

    chroot $INITRD_DIR ln -s /etc/s6 /etc/s6-rc
    rm -rf $INITRD_DIR/var/run
    chroot $INITRD_DIR ln -s /run /var/run
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
    cp -f $PKG_DIR/mkrootfs/* /etc/mkinitfs/features.d/
    mkinitfs -F "ata base network virtio" -k -t $ROOT_DIR "$(ls /lib/modules)"
    cp -aR $SRC_DIR/rootfs/* $ROOT_DIR/
    #cp -a /boot/config $ISO_DIR/boot
    cp -a /boot/vmlinuz $ISO_DIR/boot/kernel

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
    chroot $ROOT_DIR passwd root -d "toor"

    # copy config files
    cp -a $CONFIG_DIR/bashrc $ROOT_DIR/root/.bashrc
    cp -a $CONFIG_DIR/htoprc $ROOT_DIR/root/.htoprc
    cp -a $CONFIG_DIR/tmux.conf $ROOT_DIR/root/.tmux.conf
    cp -a $CONFIG_DIR/multitail.conf $ROOT_DIR/etc
    cp -a $CONFIG_DIR/session $ROOT_DIR/bin
    cp -Ra $PKG_DIR/s6 $ROOT_DIR/etc

    cp -Ra $PKG_DIR/tmuxifier $ROOT_DIR/usr/lib
    chroot $ROOT_DIR ln -s /usr/lib/tmuxifier/bin/tmuxifier /usr/bin/tmuxifier
    
    chroot $ROOT_DIR ln -s /etc/s6 /etc/s6-rc
    rm -rf $ROOT_DIR/var/run
    chroot $ROOT_DIR ln -s /run /var/run

    # write rng start seed
    #dd if=/dev/random of=$ROOT_DIR/var/lib/seed count=1 bs=4096
}

# install gotty
install_gotty() {
    cp -a $BUILD_DIR/gotty $BIN_DIR
}

# install unison
install_unison() {
    cp -a $BUILD_DIR/unison/src/unison \
	  $BUILD_DIR/unison/src/unison-fsmonitor $BIN_DIR
}

# install docker
install_docker() {
    cp -a $BUILD_DIR/docker/* $BIN_DIR
}

install_portainer() {
    # Install portainer
    cp -f $PKG_DIR/portainer/images/logo.png $BUILD_DIR/portainer/images
    cp -Ra $BUILD_DIR/portainer $LIB_DIR
    mv $LIB_DIR/portainer/portainer $BIN_DIR

    # portainer db
    cp -a $PKG_DIR/portainer/portainer.db $DATA_DIR
}

prepare_iso() {
    cd $INITRD_DIR
    rm -rf usr/include var/cache/apk/* linuxrc etc/init.d etc/conf.d \
	   media .modloop srv etc/mkinitfs etc/*.apk-new etc/opt \
	   etc/sysctl.d etc/udhcpd.conf usr/local/share newroot etc/modules-load.d \
	   etc/s6/inactive usr/lib/*

    find $INITRD_DIR/etc -name "*-" | xargs rm -f
    find $INITRD_DIR -name "*.a" | xargs rm -f

    find $INITRD_DIR/usr/share -type d | grep -vE "share$|dhcpcd|fonts|keymaps" | xargs rm -rf

    # strip binary files
    bash -c "find $INITRD_DIR -type f | grep -v modules | xargs strip --strip-all &>/dev/null; exit 0"
}

# Generate final iso image
make_iso() {
    # create initrd image
    cd $INITRD_DIR
    find | cpio -o -H newc | xz --check=crc32 -9 -e --verbose > $ISO_DIR/ramdisk.img
    
    # create main sqashfs image
    #mksquashfs $ROOT_DIR $ISO_DIR/rootfs.img -b 1048576 -comp xz -Xdict-size 100%

    # copy linux kernel and bootloader stuff
    cp -a /boot/vmlinuz $ISO_DIR/kernel
    cp -Ra $PKG_DIR/syslinux $ISO_DIR/syslinux

    # Builds an image that can be used as an ISO and a disk image
    mkdir -p $SRC_DIR/dist
    chown -R root:root $INITRD_DIR
    xorriso -as mkisofs \
	-publisher "DockerVM" \
        -c syslinux/boot.cat \
	-b syslinux/isolinux.bin \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
	-eltorito-alt-boot \
	-e /ramdisk.img \
	-no-emul-boot -isohybrid-gpt-basdat \
	-o "$SRC_DIR/dist/dockervm.iso" $ISO_DIR
}

py_install() {
    pip3 install container-transform
    
    #cd $BUILD_DIR/docker-registry-ui
    #pip3 install -r requirements.txt
}

py_cleanup() {
    # cleanup
    find $PY_DIR -type d | grep -E "test|pycache|info$" | xargs rm -rf
    find $PY_DIR/encodings -type f | grep -vE "init|undef|unicode|alias|utf|latin" | xargs rm

    cd $PY_DIR
    rm -rf email config-3.5m ctypes/macholib distutils distutils/command/wininst-* \
           ensurepip idlelib lib2to3 pydoc_data site-packages/pip* site-packages/setuptools* \
           sqlite3 tkinter turtle* unittest venv wsgiref xml/dom \
           multiprocessing xml site-packages/pkg_resources html xmlrpc
       
    cd $PY_DIR/lib-dynload
    rm -f _codecs* _bz2* _lzma* _sqlite* audioop* ossaudiodev*
}

log() {
    echo $'\e['"1;31m$(date "+%Y-%m-%d %H:%M:%S") [$(basename $0)] ${@}"$'\e[0m'
}
