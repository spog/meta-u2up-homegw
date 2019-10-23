FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://firewalld.conf \
"

do_install_append() {
        install -m0644 ${WORKDIR}/firewalld.conf ${D}${sysconfdir}/firewalld
}

