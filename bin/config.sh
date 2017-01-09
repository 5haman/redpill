THREADS=$(cat /proc/cpuinfo | grep processor | wc -l)

KERNELVERSION="4.4.39"
PORTAINER_VERSION="1.11.0"
UNISON_VERSION="2.48.4"

BUILD_DIR="$SRC_DIR/build"
CONFIG_DIR="$SRC_DIR/pkg/shell"
PKG_DIR="$SRC_DIR/pkg"
ISO_DIR="$BUILD_DIR/iso"
ROOT_DIR="$BUILD_DIR/rootfs"
INITRD_DIR="$BUILD_DIR/initrd"
PY_DIR="/usr/lib/python3.5"

DATA_DIR="$ROOT_DIR/data"
BIN_DIR="$ROOT_DIR/usr/bin"
LIB_DIR="$ROOT_DIR/usr/lib"

DOCKER_URL="https://get.docker.com/builds/Linux/x86_64"
GOTTY_URL="https://github.com/yudai/gotty/releases/download"
PORTAINER_URL="https://github.com/portainer/portainer/releases/download"
UNISON_URL="https://github.com/bcpierce00/unison/archive"
