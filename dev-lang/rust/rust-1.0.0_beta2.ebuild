# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

PYTHON_COMPAT=( python2_7 )

inherit eutils python-any-r1

RUST_CHANNEL="beta"

BETA_NUM="${PV##*beta}"
MY_PV="${PV/_/-}"
# beta => beta BUT beta2 => beta.2
[ -n "${BETA_NUM}" ] && MY_PV="${MY_PV/beta/beta.}"
MY_P="rustc-${MY_PV}"

DESCRIPTION="Systems programming language from Mozilla"
HOMEPAGE="http://www.rust-lang.org/"

SRC_URI="http://static.rust-lang.org/dist/${MY_P}-src.tar.gz
	x86?   ( http://static.rust-lang.org/stage0-snapshots/rust-stage0-2015-03-27-5520801-linux-i386-1ef82402ed16f5a6d2f87a9a62eaa83170e249ec.tar.bz2 )
	amd64? ( http://static.rust-lang.org/stage0-snapshots/rust-stage0-2015-03-27-5520801-linux-x86_64-ef2154372e97a3cb687897d027fd51c8f2c5f349.tar.bz2 )"

LICENSE="|| ( MIT Apache-2.0 ) BSD-1 BSD-2 BSD-4 UoI-NCSA"
SLOT="1.0"
KEYWORDS="~amd64 ~x86"

IUSE="clang debug doc libcxx +system-llvm"
REQUIRED_USE="libcxx? ( clang )"

CDEPEND="libcxx? ( sys-libs/libcxx )
	>=app-eselect/eselect-rust-0.2_pre20150206
	!dev-lang/rust:0
"
DEPEND="${CDEPEND}
	${PYTHON_DEPS}
	>=dev-lang/perl-5.0
	clang? ( sys-devel/clang )
	system-llvm? ( >=sys-devel/llvm-3.6.0[multitarget(-)] )
"
RDEPEND="${CDEPEND}
"

S=${WORKDIR}/${MY_P}

src_unpack() {
	unpack "${MY_P}-src.tar.gz" || die
	mkdir "${MY_P}/dl" || die
	cp "${DISTDIR}/rust-stage0"* "${MY_P}/dl/" || die
}

src_prepare() {
	local postfix="gentoo-${SLOT}"
	sed -i -e "s/CFG_FILENAME_EXTRA=.*/CFG_FILENAME_EXTRA=${postfix}/" mk/main.mk || die
}

src_configure() {
	export CFG_DISABLE_LDCONFIG="notempty"

	"${ECONF_SOURCE:-.}"/configure \
		--prefix="${EPREFIX}/usr" \
		--libdir="${EPREFIX}/usr/lib/${P}" \
		--mandir="${EPREFIX}/usr/share/${P}/man" \
		--release-channel=${RUST_CHANNEL} \
		--disable-manage-submodules \
		$(use_enable clang) \
		$(use_enable debug) \
		$(use_enable debug llvm-assertions) \
		$(use_enable !debug optimize) \
		$(use_enable !debug optimize-cxx) \
		$(use_enable !debug optimize-llvm) \
		$(use_enable !debug optimize-tests) \
		$(use_enable doc docs) \
		$(use_enable libcxx libcpp) \
		$(usex system-llvm "--llvm-root=${EPREFIX}/usr" " ") \
		|| die
}

src_compile() {
	emake VERBOSE=1
}

src_install() {
	default

	mv "${D}/usr/bin/rustc" "${D}/usr/bin/rustc-${PV}" || die
	mv "${D}/usr/bin/rustdoc" "${D}/usr/bin/rustdoc-${PV}" || die
	mv "${D}/usr/bin/rust-gdb" "${D}/usr/bin/rust-gdb-${PV}" || die

	dodoc COPYRIGHT LICENSE-APACHE LICENSE-MIT

	rm "${D}/usr/share/doc/rust" -rf

	# le kludge that fixes https://github.com/Heather/gentoo-rust/issues/41
	mv "${D}/usr/lib/rust-${PV}/rust-${PV}/rustlib"/* "${D}/usr/lib/rust-${PV}/rustlib/"
	rmdir "${D}/usr/lib/rust-${PV}/rust-${PV}/rustlib"
	mv "${D}/usr/lib/rust-${PV}/rust-${PV}/"/* "${D}/usr/lib/rust-${PV}/"
	rmdir "${D}/usr/lib/rust-${PV}/rust-${PV}/"

	mv "${D}/usr/share/doc/rust"/* "${D}/usr/share/doc/rust-${PV}/"
	rmdir "${D}/usr/share/doc/rust/"

	cat <<-EOF > "${T}"/50${P}
	LDPATH="/usr/lib/${P}"
	MANPATH="/usr/share/${P}/man"
	EOF
	doenvd "${T}"/50${P}

	dodir /etc/env.d/rust
	touch "${D}/etc/env.d/rust/provider-${P}" || die
}

pkg_postinst() {
	eselect rust update --if-unset

	elog "Rust uses slots now, use 'eselect rust list'"
	elog "and 'eselect rust set' to list and set rust version."
	elog "For more information see 'eselect rust help'"
	elog "and http://wiki.gentoo.org/wiki/Project:Eselect/User_guide"

	elog "Rust installs a helper script for calling GDB now,"
	elog "for your convenience it is installed under /usr/bin/rust-gdb-${PV}."

	if has_version app-editors/emacs || has_version app-editors/emacs-vcs; then
		elog "install app-emacs/rust-mode to get emacs support for rust."
	fi

	if has_version app-editors/gvim || has_version app-editors/vim; then
		elog "install app-vim/rust-mode to get vim support for rust."
	fi

	if has_version 'app-shells/zsh'; then
		elog "install app-shells/rust-zshcomp to get zsh completion for rust."
	fi
}

pkg_postrm() {
	eselect rust unset --if-invalid
}
