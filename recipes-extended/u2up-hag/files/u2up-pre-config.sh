#!/bin/bash
#
# A dialog menu based u2up-pc-installer program
#
#set -xe

U2UP_INSTALL_BASH_LIB="/lib/u2up/u2up-install-bash-lib"
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	echo "U2UP boot pre-configuration failed (missing: ${U2UP_INSTALL_BASH_LIB} - entering RESCUE)!"
	/bin/systemctl isolate rescue.target
	exit 1
fi
source ${U2UP_INSTALL_BASH_LIB}

echo "Hello" > /dev/console
#sleep 10
set -x
evaluate_u2up_configurations &> /dev/console
rv=$?
if [ $rv -ne 0 ]; then
	echo "U2UP boot pre-configuration failed (entering RESCUE)!"
	/bin/systemctl isolate rescue.target
	exit 1
fi
echo "Bye" > /dev/console

#/bin/systemctl isolate multi-user.target &> /dev/console

