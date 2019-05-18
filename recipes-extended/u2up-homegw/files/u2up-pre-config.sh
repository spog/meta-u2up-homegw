#!/bin/bash
#
# A dialog menu based u2up-pc-installer program
#
#set -xe

echo -e "U2UP boot pre-configuration TIMED-OUT (PARTIALLY configured)!\n" > /etc/issue.d/z99-u2up.issue

U2UP_INSTALL_BASH_LIB="/lib/u2up/u2up-install-bash-lib"
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	echo -e "U2UP boot pre-configuration failed (missing: ${U2UP_INSTALL_BASH_LIB} - NOT configured)!\n" > /etc/issue.d/z99-u2up.issue
	exit 1
fi
source ${U2UP_INSTALL_BASH_LIB}

echo "Hello" > /dev/console
#sleep 30
#set -x
evaluate_u2up_configurations &> /dev/console
rv=$?
if [ $rv -ne 0 ]; then
	echo -e "U2UP boot pre-configuration failed (PARTIALLY configured)!\n" > /etc/issue.d/z99-u2up.issue
	exit 1
fi
echo "Bye" > /dev/console

echo -e "U2UP (use your admin-user to login)!\n" > /etc/issue.d/z99-u2up.issue

