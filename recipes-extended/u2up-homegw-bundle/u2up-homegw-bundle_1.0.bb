SUMMARY = "U2UP HOMEGW BUNDLE archive creation recipe"
HOMEPAGE = "http://www...."
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b6fdc2ec7367311f970da8ef475e6fd1"
SECTION = "console/tools"
PR = "r1"

SRC_URI = " \
   file://LICENSE \
"

inherit deploy

do_patch () {
	mkdir -p ${S}
	cp -pf ${WORKDIR}/LICENSE ${S}/
}

do_deploy() {
	cd ${BUILDIR}/tmp/deploy/images/${MACHINE}
#	tar cvhf ${PN}-${PV}-${MACHINE}.tar systemd-bootx64.efi bzImage-${MACHINE}.bin modules-${MACHINE}.tgz microcode.cpio u2up-homegw-image-full-cmdline-${MACHINE}.tar.gz
	tar cvhf ${PN}-${PV}-${MACHINE}.tar systemd-bootx64.efi bzImage-${MACHINE}.bin microcode.cpio u2up-homegw-image-full-cmdline-${MACHINE}.tar.gz
	sha256sum ${PN}-${PV}-${MACHINE}.tar > ${PN}-${PV}-${MACHINE}.tar.sha256
	sha256sum -c ${PN}-${PV}-${MACHINE}.tar.sha256
	ret=$?
	rm -f ${PN}.tar
	rm -f ${PN}.tar.sha256
	if [ $ret -eq 0 ]; then
		ln -sf ${PN}-${PV}-${MACHINE}.tar ${PN}.tar
		ln -sf ${PN}-${PV}-${MACHINE}.tar.sha256 ${PN}.tar.sha256
		cd ${BUILDIR}/tmp/deploy/rpm
		ln -sf ../images/${MACHINE}/u2up-homegw-bundle.tar
		ln -sf ../images/${MACHINE}/u2up-homegw-bundle.tar.sha256
	fi
}

addtask deploy before do_build after do_patch

do_deploy[nostamp] = "1"
do_deploy[depends] = "u2up-homegw-image-full-cmdline:do_image_complete"

RDEPENDS_${PN} = "bash tar"
