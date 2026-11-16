# Third-party notices

VirtualizationKit itself is licensed under the Apache License, Version 2.0 (see `LICENSE`). Its QEMU back-end embeds an emulator payload built from the components below, each under its own licence. The full licence texts are in the `ThirdPartyLicenses` folder of each release, taken from the sources listed here.

| Component | Licence | Source | SHA-256 |
|---|---|---|---|
| PCRE2 | BSD-3-Clause | https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.bz2 | `d34f02e113cf7193a1ebf2770d3ac527088d485d4e047ed10e5d217c6ef5de96` |
| GLib | LGPL-2.1-or-later | https://download.gnome.org/sources/glib/2.82/glib-2.82.4.tar.xz | `37dd0877fe964cd15e9a2710b044a1830fb1bd93652a6d0cb6b8b2dff187c709` |
| pixman | MIT | https://cairographics.org/releases/pixman-0.44.2.tar.gz | `6349061ce1a338ab6952b92194d1b0377472244208d47ff25bef86fc71973466` |
| libslirp | BSD-3-Clause | https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.8.0/libslirp-v4.8.0.tar.gz | `2a98852e65666db313481943e7a1997abff0183bd9bea80caec1b5da89fda28c` |
| OpenSSL | Apache-2.0 | https://github.com/openssl/openssl/releases/download/openssl-3.5.4/openssl-3.5.4.tar.gz | `967311f84955316969bdb1d8d4b983718ef42338639c621ec4c34fddef355e99` |
| libtpms | BSD-3-Clause | https://github.com/stefanberger/libtpms/archive/refs/tags/v0.10.1.tar.gz | `ebc24f3191d90f6cf0b4d4200cd876db4bd224b3c565708bbea0a82ee275e0fb` |
| swtpm | BSD-3-Clause | https://github.com/stefanberger/swtpm/archive/refs/tags/v0.10.1.tar.gz | `f8da11cadfed27e26d26c5f58a7b8f2d14d684e691927348906b5891f525c684` |
| libtasn1 | LGPL-2.1-or-later | https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz | `92e0e3bd4c02d4aeee76036b2ddd83f0c732ba4cda5cb71d583272b23587a76c` |
| JSON-GLib | LGPL-2.1-or-later | https://download.gnome.org/sources/json-glib/1.10/json-glib-1.10.6.tar.xz | `77f4bcbf9339528f166b8073458693f0a20b77b7059dbc2db61746a1928b0293` |
| QEMU (UTM fork) | GPL-2.0-only, with parts under compatible licences | https://github.com/utmapp/qemu/releases/download/v10.0.12-utm/qemu-10.0.12-utm.tar.xz | `7c9605290b34152debb842e965a55d2e4fbba4793e536ab677b4027e5dc0ba1a` |
| EDK II firmware (shipped with QEMU) | BSD-2-Clause-Patent | Included in the QEMU source above | |

## Sources

QEMU is licensed under the GNU General Public License, version 2, and several components under the GNU Lesser General Public License. Each release is published together with `VirtualizationKit-sources.tar.gz`, which contains the exact source archives listed above and the scripts used to build and embed the payload (`Third-Party/` and `QEMUSupport/`).
