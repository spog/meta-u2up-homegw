FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://dnsmasq-noresolvconf.service \
"

