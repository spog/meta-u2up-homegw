FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://fetchmail.service \
    file://fetchmailrc \
"

do_install_append() {
	install -d ${D}/${systemd_unitdir}/system
	install -d ${D}/etc
        install -m0644 ${WORKDIR}/fetchmail.service ${D}/${systemd_unitdir}/system
        install -m0600 ${WORKDIR}/fetchmailrc ${D}/etc
}

FILES_${PN} += "${systemd_unitdir}"
FILES_${PN} += "/etc"

