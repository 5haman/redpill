# pkg: iptables

pkgname=iptables
pkgver=1.6.0
pkgdesc="Linux kernel firewall, NAT and packet mangling tools"
url="http://www.netfilter.org/projects/iptables/index.html"
source="http://ftp.netfilter.org/pub/iptables/iptables-$pkgver.tar.bz2
iptables-1.6.0-musl-fixes.patch"

_builddir="$srcdir"/$pkgname-$pkgver

download() {
    
}

prepare() {
cd "$_builddir"
    local i
    for i in $source; do
        case $i in
        *.patch) msg $i; patch -p1 -i "$srcdir"/$i || return 1;;
        esac
    done

}

build() {
    cd "$_builddir"
}

package() {
    cd "$_builddir"
    make -j1 install DESTDIR="$pkgdir" || return 1

    mkdir -p "$pkgdir"/var/lib/iptables \
        "$pkgdir"/etc/iptables \
        || return 1
}
