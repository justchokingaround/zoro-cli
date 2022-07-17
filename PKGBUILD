# Maintainer: change me <mark at sgtxd dot de >
pkgname='zoro-cli-git'
_pkgname='zoro-cli'
pkgver=r5.8f2b118
pkgrel=1
pkgdesc="-"
arch=('any')
url="https://github.com/justchokingaround/zoro-cli"
license=('GPL3')
depends=('grep' 'sed' 'curl' 'mpv')
makedepends=('git')
provides=('zoro')
source=('zoro-cli::git+https://github.com/justchokingaround/zoro-cli.git')
md5sums=('SKIP')

pkgver() {
        cd "$srcdir/${_pkgname}"
        printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
        cd "$srcdir/${_pkgname%-VCS}"
        install -Dm755 "./zoro.sh" "$pkgdir/usr/bin/zoro"
}
