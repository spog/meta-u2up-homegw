SUMMARY = "Boot-time U2UP-HAG pre-configuration support"
HOMEPAGE = "http://www..."
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b6fdc2ec7367311f970da8ef475e6fd1"
SECTION = "console/tools"
DEPENDS = "bash"
PR = "r1"

SRC_URI = " \
           file://LICENSE \
           file://u2up-hag.sh \
           file://u2up-pre-config.sh \
           file://u2up-install-bash-lib \
           file://u2up-pre-config.target \
           file://u2up-pre-config.service \
"

do_patch () {
	mv ${WORKDIR}/LICENSE ${S}/
	mv ${WORKDIR}/u2up-hag.sh ${S}/
	mv ${WORKDIR}/u2up-pre-config.sh ${S}/
	mv ${WORKDIR}/u2up-install-bash-lib ${S}/
	mv ${WORKDIR}/u2up-pre-config.target ${S}/
	mv ${WORKDIR}/u2up-pre-config.service ${S}/
	echo "%wheel ALL=(ALL) ALL" > ${S}/enable_wheel
	echo "[ \$(id -Gn | grep -c wheel) -eq 1 ] && PATH=\$PATH:/usr/local/sbin:/usr/sbin:/sbin" > ${S}/wheel.sh
}

do_install () {
	install -d ${D}/etc/systemd/system/u2up-pre-config.target.wants
	install -m 0644 ${S}/u2up-pre-config.service ${D}/etc/systemd/system/
	install -m 0750 -d ${D}/etc/sudoers.d
	install -m 0644 ${S}/enable_wheel ${D}/etc/sudoers.d/
	install -m 0755 -d ${D}/etc/profile.d
	install -m 0644 ${S}/wheel.sh ${D}/etc/profile.d/
	install -d ${D}/etc/u2up-conf.d
	install -d ${D}/lib/systemd/system
	install -m 0644 ${S}/u2up-pre-config.target ${D}/lib/systemd/system/
	install -d ${D}/lib/u2up
	install -m 0755 ${S}/u2up-install-bash-lib ${D}/lib/u2up/
	install -d ${D}/usr/bin
	install -m 0755 ${S}/u2up-hag.sh ${D}/usr/bin/
	install -m 0755 ${S}/u2up-pre-config.sh ${D}/usr/bin/
}

pkg_postinst_${PN}() {
#!/bin/sh

rm -f $D/etc/systemd/system/u2up-pre-config.target.wants/u2up-pre-config.service
ln -s /etc/systemd/system/u2up-pre-config.service $D/etc/systemd/system/u2up-pre-config.target.wants/u2up-pre-config.service
}

FILES_${PN} += "etc lib usr"

RDEPENDS_${PN} = "bash"

