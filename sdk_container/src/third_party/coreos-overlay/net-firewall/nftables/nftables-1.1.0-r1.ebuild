# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_OPTIONAL=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..13} )
VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/netfilter.org.asc
inherit edo linux-info distutils-r1 systemd verify-sig

DESCRIPTION="Linux kernel firewall, NAT and packet mangling tools"
HOMEPAGE="https://netfilter.org/projects/nftables/"

if [[ ${PV} =~ ^[9]{4,}$ ]]; then
	inherit autotools git-r3
	EGIT_REPO_URI="https://git.netfilter.org/${PN}"
	BDEPEND="app-alternatives/yacc"
else
	SRC_URI="
		https://netfilter.org/projects/nftables/files/${P}.tar.xz
		verify-sig? ( https://netfilter.org/projects/nftables/files/${P}.tar.xz.sig )
	"
	KEYWORDS="amd64 arm arm64 ~hppa ~loong ~mips ppc ppc64 ~riscv sparc x86"
	BDEPEND="verify-sig? ( sec-keys/openpgp-keys-netfilter )"
fi

# See COPYING: new code is GPL-2+, existing code is GPL-2
LICENSE="GPL-2 GPL-2+"
SLOT="0/1"
IUSE="debug doc +gmp json libedit python +readline static-libs test xtables"
RESTRICT="!test? ( test )"

RDEPEND="
	>=net-libs/libmnl-1.0.4:=
	>=net-libs/libnftnl-1.2.7:=
	gmp? ( dev-libs/gmp:= )
	json? ( dev-libs/jansson:= )
	python? ( ${PYTHON_DEPS} )
	readline? ( sys-libs/readline:= )
	xtables? ( >=net-firewall/iptables-1.6.1:= )
"
DEPEND="${RDEPEND}"
BDEPEND+="
	app-alternatives/lex
	virtual/pkgconfig
	doc? (
		app-text/asciidoc
		>=app-text/docbook2X-0.8.8-r4
	)
	python? ( ${DISTUTILS_DEPS} )
"

REQUIRED_USE="
	python? ( ${PYTHON_REQUIRED_USE} )
	libedit? ( !readline )
"

PATCHES=(
	"${FILESDIR}"/nftables-1.1.0-revert-firewalld-breaking-change.patch
)

src_prepare() {
	default

	if [[ ${PV} =~ ^[9]{4,}$ ]] ; then
		eautoreconf
	fi

	if use python; then
		pushd py >/dev/null || die
		distutils-r1_src_prepare
		popd >/dev/null || die
	fi
}

src_configure() {
	local myeconfargs=(
		--sbindir="${EPREFIX}"/sbin
		$(use_enable debug)
		$(use_enable doc man-doc)
		$(use_with !gmp mini_gmp)
		$(use_with json)
		$(use_with libedit cli editline)
		$(use_with readline cli readline)
		$(use_enable static-libs static)
		$(use_with xtables)
	)

	econf "${myeconfargs[@]}"

	if use python; then
		pushd py >/dev/null || die
		distutils-r1_src_configure
		popd >/dev/null || die
	fi
}

src_compile() {
	default

	if use python; then
		pushd py >/dev/null || die
		distutils-r1_src_compile
		popd >/dev/null || die
	fi
}

src_test() {
	emake check

	if [[ ${EUID} == 0 ]]; then
		edo tests/shell/run-tests.sh -v
	else
		ewarn "Skipping shell tests (requires root)"
	fi

	if use python; then
		pushd tests/py >/dev/null || die
		distutils-r1_src_test
		popd >/dev/null || die
	fi
}

python_test() {
	if [[ ${EUID} == 0 ]]; then
		edo "${EPYTHON}" nft-test.py
	else
		ewarn "Skipping Python tests (requires root)"
	fi
}

src_install() {
	default
	find "${ED}" -type f -name "*.la" -delete || die
}
