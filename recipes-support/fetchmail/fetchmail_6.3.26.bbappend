FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://fetchmail.service \
    file://fetchmailrc \
"

do_install_append() {
        install -m0644 ${WORKDIR}/fetchmail.service ${D}/lib/systemd/system
        install -m0600 ${WORKDIR}/fetchmailrc ${D}/etc
}

