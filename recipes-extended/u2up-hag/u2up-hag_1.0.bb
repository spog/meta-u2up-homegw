SUMMARY = "Disk partition editing/resizing utility"
HOMEPAGE = "http://www.gnu.org/software/parted/parted.html"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=b6fdc2ec7367311f970da8ef475e6fd1"
SECTION = "console/tools"
DEPENDS = "bash"
PR = "r1"

SRC_URI = " \
           file://LICENSE \
           file://u2up-hag.sh \
"

do_patch () {
	cp -p ${WORKDIR}/LICENSE ${S}/
	cp -p ${WORKDIR}/u2up-hag.sh ${S}/
}

do_install () {
	install -d ${D}/usr/bin
	install -m 0755 ${S}/u2up-hag.sh ${D}/usr/bin/
}

RDEPENDS_${PN} = "bash"

