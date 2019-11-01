FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://adddovecotuser \
    file://deldovecotuser \
    file://dovecot-2.3.0.1-libxcrypt.patch \
"

do_install_append() {
        install -m0750 ${WORKDIR}/adddovecotuser ${D}/usr/sbin
        install -m0750 ${WORKDIR}/deldovecotuser ${D}/usr/sbin
}

