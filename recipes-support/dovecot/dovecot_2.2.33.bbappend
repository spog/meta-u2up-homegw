FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://dovecot-2.3.0.1-libxcrypt.patch \
"

