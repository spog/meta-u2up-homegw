DESCRIPTION = "A console-only image with more full-featured Linux system \
functionality installed."

IMAGE_FEATURES += "splash ssh-server-openssh"
IMAGE_FEATURES += "package-management"

IMAGE_INSTALL = "\
    packagegroup-core-boot \
    packagegroup-core-full-cmdline \
    ${CORE_IMAGE_EXTRA_INSTALL} \
    strace \
    nodejs \
    nodejs-npm \
    openssl-bin \
    cockpit \
    cockpit-bridge \
    cockpit-dashboard \
    cockpit-networkmanager \
    cockpit-pcp \
    cockpit-system \
    cockpit-ws \
    networkmanager \
    firewalld \
    u2up-hag \
    "

SYSTEMD_DEFAULT_TARGET = "u2up-pre-config.target"

inherit core-image
