threads=$(cat /proc/cpuinfo | grep processor | wc -l)
pkgext=spk

srcdir="$SRC_DIR/.build"
workdir="$SRC_DIR/pkg"
pkgdir="$SRC_DIR/.cache"

KERNELVERSION="4.4.39"
BUILD_DIR="$SRC_DIR/.build"
CONFIG_DIR="$SRC_DIR/pkg/shell"
PKG_DIR="$SRC_DIR/pkg"
ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/rootfs"
DATA_DIR="$ROOT_DIR/data"
BIN_DIR="$ROOT_DIR/usr/bin"
LIB_DIR="$ROOT_DIR/usr/lib"
