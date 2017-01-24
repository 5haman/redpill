#!/usr/bin/env bash

set -ex

ROOTFS=${ROOTFS:-/rootfs}
BUILDDIR=${BUILDDIR:-/opt/build}

# build buildroot rootfs
make O=$BUILDDIR/output nconfig
make O=$BUILDDIR/output silentoldconfig
make O=$BUILDDIR/output all

# overwrite redpill rootfs with new content
rm -rf $ROOTFS/*
rsync -avr $BUILDDIR/output/target/ $ROOTFS/

# clean unneded files/dirs
rm -rf $(cat /tmp/remove.files | awk '{ print "$ROOTFS" $1 }' | tr "\n" " ")
find $ROOTFS/usr/libexec -type f | grep -vE "log_db_daemon|unlinkd" | xargs rm -f
find $ROOTFS/usr/share/errors -type d | grep -vE "en$|errors$|templates$" | xargs rm -rf
find $ROOTFS/usr/lib -type d | grep -vE "lib$|mdev|dhcpcd" | xargs rm -rf
find $ROOTFS/usr/share -type d | grep -vE "share$|dhcpcd|terminfo" | xargs rm -rf

cd $ROOTFS
mkdir -p etc/dropbear etc/s6 var/log var/lock opt libexec var/run/s6 var/cache
ln -s var/run run

cd $ROOTFS/etc
ln -sf s6 s6-rc

tmpdir=$(mktemp -d /tmp/tclroot.XXX)
cd $tmpdir
curl -sSL http://distro.ibiblio.org/tinycorelinux/7.x/x86_64/release/distribution_files/rootfs64.gz \
          | gunzip | cpio -f -i -H newc -d --no-absolute-filenames

rsync -avr $tmpdir/dev/ $ROOTFS/dev/
