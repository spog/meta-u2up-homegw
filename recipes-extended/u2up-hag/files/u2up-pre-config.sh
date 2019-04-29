#!/bin/bash
#
# A dialog menu based u2up-pc-installer program
#
#set -xe

U2UP_INSTALL_BASH_LIB="/lib/u2up/u2up-install-bash-lib"
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	echo "Program terminated (missing: ${U2UP_INSTALL_BASH_LIB})!"
	/bin/systemctl isolate multi-user.target
	exit 1
fi
source ${U2UP_INSTALL_BASH_LIB}

echo "Hello" > /dev/console
sleep 10
echo "Bye" > /dev/console

#/bin/systemctl isolate multi-user.target &> /dev/console

