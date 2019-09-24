#!/bin/bash
#
# A dialog menu based u2up-pc-installer program
#
trap "echo 'Exited: '${0} >&2; exec 2>&-" EXIT
exec 2> >(logger -s -t $(basename $0))
echo >&2
echo "Started: ${0}" >&2
#set -x

U2UP_CONF_DIR_PREFIX=""
U2UP_INSTALL_BASH_LIB="/lib/u2up/u2up-install-bash-lib"
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	echo "Program terminated (missing: ${U2UP_INSTALL_BASH_LIB})!" >&2
	exit 1
fi
if [ -z "${U2UP_INSTALL_BASH_LIB_SOURCED}" ]; then
	source ${U2UP_INSTALL_BASH_LIB}
fi
U2UP_INSTALL_DIALOG_LIB="/lib/u2up/u2up-install-dialog-lib"
if [ ! -f "${U2UP_INSTALL_DIALOG_LIB}" ]; then
	echo "Program terminated (missing: ${U2UP_INSTALL_DIALOG_LIB})!" >&2
	exit 1
fi
if [ -z "${U2UP_INSTALL_DIALOG_LIB_SOURCED}" ]; then
	source ${U2UP_INSTALL_DIALOG_LIB}
fi

U2UP_IMAGES_DIR="/var/lib/u2up-images"
U2UP_IMAGES_BUNDLE_NAME="u2up-homegw-bundle"
U2UP_IMAGES_BUNDLE_ARCHIVE=${U2UP_IMAGES_DIR}/${U2UP_IMAGES_BUNDLE_NAME}.tar
if [ ! -f "${U2UP_IMAGES_BUNDLE_ARCHIVE}" ]; then
	echo "Program terminated (missing: ${U2UP_IMAGES_BUNDLE_ARCHIVE})!" >&2
	exit 1
fi
U2UP_IMAGES_BUNDLE_ARCHIVE_SUM=${U2UP_IMAGES_DIR}/${U2UP_IMAGES_BUNDLE_NAME}.tar.sha256
if [ ! -f "${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}" ]; then
	echo "Program terminated (missing: ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM})!" >&2
	exit 1
fi

cd ${U2UP_IMAGES_DIR}
ln -sf $(basename ${U2UP_IMAGES_BUNDLE_ARCHIVE}) $(cat ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM} | sed -e 's%^.* %%g')
sha256sum -c ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
if [ $? -ne 0 ]; then
	echo "Program terminated (checksum mismatch: ${U2UP_IMAGES_BUNDLE_ARCHIVE})!" >&2
	exit 1
fi
cd -

MACHINE="intel-corei7-64"

U2UP_FS_IMAGE_ARCHIVE=u2up-homegw-image-full-cmdline
#U2UP_KERNEL_MODULES_ARCHIVE=modules
U2UP_KERNEL_IMAGE=bzImage
U2UP_INITRD_IMAGE=microcode
U2UP_EFI_FALLBACK_IMAGE=bootx64.efi

tar tvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} ${U2UP_FS_IMAGE_ARCHIVE}-${MACHINE}.tar.gz
if [ $? -ne 0 ]; then
	echo "Program terminated (bundle not containing: ${U2UP_FS_IMAGE_ARCHIVE}-${MACHINE}.tar.gz)!" >&2
	exit 1
fi
#tar tvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} ${U2UP_KERNEL_MODULES_ARCHIVE}-${MACHINE}.tgz
#if [ $? -ne 0 ]; then
#	echo "Program terminated (bundle not containing: ${U2UP_KERNEL_MODULES_ARCHIVE}-${MACHINE}.tgz)!" >&2
#	exit 1
#fi
tar tvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} ${U2UP_KERNEL_IMAGE}-${MACHINE}.bin
if [ $? -ne 0 ]; then
	echo "Program terminated (bundle not containing: ${U2UP_KERNEL_IMAGE}-${MACHINE}.bin)!" >&2
	exit 1
fi
tar tvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} ${U2UP_INITRD_IMAGE}.cpio
if [ $? -ne 0 ]; then
	echo "Program terminated (bundle not containing: ${U2UP_INITRD_IMAGE}.cpio)!" >&2
	exit 1
fi
tar tvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} systemd-${U2UP_EFI_FALLBACK_IMAGE}
if [ $? -ne 0 ]; then
	echo "Program terminated (bundle not containing: systemd-${U2UP_EFI_FALLBACK_IMAGE})!" >&2
	exit 1
fi
echo "Extracting U2UP_IDS:" >&2
tar xvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} -C ${U2UP_CONF_DIR} ${U2UP_IDS_CONF_FILE}
if [ $? -ne 0 ]; then
	echo "Program terminated (bundle not containing: ${U2UP_IDS_CONF_FILE})!" >&2
	exit 1
fi

echo "press enter to continue..." >&2
read

source ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0
U2UP_BACKTITLE="U2UP installer setup"

display_result() {
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "$1" \
		--no-collapse \
		--msgbox "$2" 6 75
}

display_msg() {
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "$1" \
		--cr-wrap \
		--no-collapse \
		--msgbox "$2" $3 75
}

display_yesno() {
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "$1" \
		--cr-wrap \
		--no-collapse \
		--yesno "$2" $3 75
}

get_item_selection() {
	echo $@ | sed 's/RENAMED //' | sed 's/: .*/:/'
}

display_keymap_submenu() {
	local rv=1
	local keymap_current=$1
	menu=""

	for name in $(find /usr/share/keymaps | grep "gz" | sed 's%.*/%%' | sort); do
		temp="$(basename ${name} .map.gz)"
		menu="$menu $temp $temp "
	done
	exec 3>&1
	selection=$(dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "Keyboard mapping selection" \
		--clear \
		--no-tags \
		--default-item "$keymap_current" \
		--cancel-label "Cancel" \
		--menu "Please select:" $HEIGHT $WIDTH 0 \
		${menu} \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	store_keymap_selection $selection
	rv=$?
	if [ $rv -eq 0 ]; then
		enable_keymap_selection
	fi
}

display_target_disk_submenu() {
	local target_disk_current=$1
	local radiolist=""
	local tag="start_tag"

	current_root=$(lsblk -r | grep " /$" | sed 's/[0-9].*//')
	radiolist=$(lsblk -ir -o NAME,SIZE,MODEL | grep -v $current_root | sed 's/x20//g' | sed 's/\\//g' | while read line; do
		set -- $line
		if [ -n "$1" ] && [ "$1" != "NAME" ] && [[ "$1" != "$tag"* ]]; then
			tag=$1
			shift
			if [ -n "$target_disk_current" ] && [ "$tag" == "$target_disk_current" ]; then
				echo -n "${tag}|"$@"|on|"
			else
				echo -n "${tag}|"$@"|off|"
			fi
		fi
	done)

	exec 3>&1
	selection=$(IFS='|'; \
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "Target disk selection" \
		--clear \
		--cancel-label "Cancel" \
		--radiolist "Please select:" $HEIGHT $WIDTH 0 \
		${radiolist} \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	store_target_disk_selection $selection
}

display_net_internal_ifname_submenu() {
	local net_internal_ifname_current=$1
	local radiolist=""
	local tag="start_tag"
	local ifname=""
	local mac=""

	radiolist=$(ip link | grep "BROADCAST,MULTICAST" | sed 's/[0-9]*: //' | sed 's/: .*//g' | while read ifname; do
		if [ -n "$ifname" ] && [[ "$ifname" != "$tag"* ]]; then
			tag=$ifname
			mac="$(ip link show dev $ifname | grep "link\/ether" | sed 's/ *link\/ether *//' | sed 's/ .*//')"
			if [ -n "$net_internal_ifname_current" ] && [ "$tag" == "$net_internal_ifname_current" ]; then
				echo -n "${tag}|"$mac"|on|"
			else
				echo -n "${tag}|"$mac"|off|"
			fi
		fi
	done)

	exec 3>&1
	selection=$(IFS='|'; \
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "Network internal interface selection" \
		--clear \
		--cancel-label "Cancel" \
		--radiolist "Please select:" $HEIGHT $WIDTH 0 \
		${radiolist} \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	store_net_internal_iface_selection $selection
}

display_target_part_submenu() {
	local target_disk_current=$1
	local target_part_current=$2
	local radiolist=""
	local tag="start_tag"

	radiolist=$(lsblk -ir -o NAME,SIZE,PARTUUID | grep -E "(${target_disk_current}3|${target_disk_current}4)" | while read line; do
		set -- $line
		if [ -n "$1" ] && [ "$1" != "NAME" ] && [[ "$1" != "$tag"* ]]; then
			tag=$1
			shift
			if [ -n "$target_part_current" ] && [ "$tag" == "$target_part_current" ]; then
				echo -n "${tag}|"$@"|on|"
			else
				echo -n "${tag}|"$@"|off|"
			fi
		fi
	done)

	if [ -z "$radiolist" ]; then
		store_target_part_selection ${target_disk_current}3
		return 0
	fi

	exec 3>&1
	selection=$(IFS='|'; \
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "Target disk selection" \
		--clear \
		--cancel-label "Cancel" \
		--radiolist "Please select:" $HEIGHT $WIDTH 0 \
		${radiolist} \
	2>&1 1>&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	store_target_part_selection $selection
}

check_target_disk_set() {
	if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		TARGET_DISK_SET=""
	fi
	if [ -z "$TARGET_DISK_SET" ]; then
		display_result "Target disk check" "Please select your target disk for the installation!"
		return 1
	fi
}

check_net_internal_ifname_set() {
	if [ -f "${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}
	else
		NET_INTERNAL_IFNAME_SET=""
	fi
	if [ -z "$NET_INTERNAL_IFNAME_SET" ]; then
		display_result "Network internal interface check" "Please select your network internal interface!"
		return 1
	fi
}

check_install_repo_config_set() {
	if [ -f "${U2UP_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}
	else
		INSTALL_REPO_BASE_URL_SET=""
	fi
}

check_target_part_set() {
	if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		TARGET_PART_SET=""
	fi
	if [ -z "$TARGET_PART_SET" ]; then
		display_result "Target partition check" "Please select your target partition for the installation!"
		return 1
	fi
}

check_target_part_sizes_set() {
	if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		TARGET_BOOT_PARTSZ_SET=""
	fi
	if \
		[ -z "$TARGET_BOOT_PARTSZ_SET" ] || \
		[ -z "$TARGET_LOG_PARTSZ_SET" ] || \
		[ -z "$TARGET_ROOTA_PARTSZ_SET" ] || \
		[ -z "$TARGET_ROOTB_PARTSZ_SET" ];
	then
		display_result "Target partition sizes check" "Please set your target partition sizes for the installation!"
		return 1
	fi
}

check_target_disk_configuration() {
	local rv=1
	check_target_disk_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	check_target_part_sizes_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
}

check_network_configuration() {
	if [ -f "${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}
	else
		NET_INTERNAL_IFNAME_SET=""
	fi
	if \
		[ -z "$NET_INTERNAL_IFNAME_SET" ] || \
		[ -z "$NET_INTERNAL_ADDR_MASK_SET" ] || \
		[ -z "$NET_INTERNAL_GW_SET" ] || \
		[ -z "$NET_DNS_SET" ] || \
		[ -z "$NET_DOMAINS_SET" ];
	then
		display_result "Network configuration check" "Please set your networking parameters!"
		return 1
	fi
}

check_target_configurations() {
	local rv=1
	check_target_disk_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	check_target_part_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	check_target_part_sizes_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
}

check_part_type() {
	local part_line=""
	local part_type=""

	case $1 in
	EFI)
		PART_TYPE=${PART_TYPE_EFI}
		;;
	Linux)
		PART_TYPE=${PART_TYPE_LINUX}
		;;
	*)
		return 1
		;;
	esac
	case $2 in
	boot)
		PART_NAME="${TARGET_DISK_SET}1"
		;;
	log)
		PART_NAME="${TARGET_DISK_SET}2"
		;;
	rootA)
		PART_NAME="${TARGET_DISK_SET}3"
		;;
	rootB)
		PART_NAME="${TARGET_DISK_SET}4"
		;;
	*)
		return 1
		;;
	esac
	part_line="$(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${PART_NAME}")"
	if [ -z "$part_line" ]; then
		return 1
	fi
	part_type="$(echo "${part_line[@]}" | sed 's/.*type=//' | sed 's/,.*//')"
	if [ -z "$part_type" ]; then
		return 1
	fi
	if [ "$part_type" != "$PART_TYPE" ]; then
		return 1
	fi
	return 0
}

check_part_size() {
	local part_line=""
	local part_size=""
	local sectors_in_kib=0
	(( sectors_in_kib=1024/$(cat /sys/block/${TARGET_DISK_SET}/queue/hw_sector_size) ))

	if [ $sectors_in_kib -le 0 ]; then
		retrn 1
	fi
	case $1 in
	boot)
		PART_NAME="${TARGET_DISK_SET}1"
		PART_SIZE="${TARGET_BOOT_PARTSZ_SET}"
		;;
	log)
		PART_NAME="${TARGET_DISK_SET}2"
		PART_SIZE="${TARGET_LOG_PARTSZ_SET}"
		;;
	rootA)
		PART_NAME="${TARGET_DISK_SET}3"
		PART_SIZE="${TARGET_ROOTA_PARTSZ_SET}"
		;;
	rootB)
		PART_NAME="${TARGET_DISK_SET}4"
		PART_SIZE="${TARGET_ROOTB_PARTSZ_SET}"
		;;
	*)
		return 1
		;;
	esac
	part_line="$(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${PART_NAME}")"
	if [ -z "$part_line" ]; then
		return 1
	fi
	# num 512 B sectors:
	part_size="$(echo "${part_line[@]}" | sed 's/.*size= *//' | sed 's/,.*//')"
	# num KiB:
	((part_size/=2))
	# num MiB:
	((part_size/=1024))
	# num GiB:
	((part_size/=1024))
	if [ -z "$part_size" ]; then
		return 1
	fi
	if [ "$part_size" != "$PART_SIZE" ]; then
		return 1
	fi
	return 0
}

check_current_target_disk_setup() {
	local action_name="${1}"
	local root_part_label=""
	local msg_warn=""
	local msg_fdisk="$(fdisk -l /dev/${TARGET_DISK_SET})\n"
	local msg_size=17
	local disk_change_needed=0
	local first_sector=0
	local sectors_in_kib=0
	(( sectors_in_kib=1024/$(cat /sys/block/${TARGET_DISK_SET}/queue/hw_sector_size) ))

	if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		TARGET_BOOT_PARTSZ_SET=""
	fi
	root_part_label="$(get_root_label ${TARGET_DISK_SET} ${TARGET_PART_SET})"
	if \
		[ -n "$TARGET_BOOT_PARTSZ_SET" ] && \
		[ -n "$TARGET_ROOTA_PARTSZ_SET" ] && \
		[ -n "$TARGET_ROOTB_PARTSZ_SET" ] && \
		[ -n "$TARGET_LOG_PARTSZ_SET" ]; \
	then
		# Dump current target disk setup:
		sfdisk -d /dev/${TARGET_DISK_SET} > $U2UP_TARGET_DISK_SFDISK_DUMP
		rm -f $U2UP_TARGET_DISK_SFDISK_BASH

		# Warn, if partition table NOT GPT: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "label:" | grep "gpt" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! Partition table - wrong type\n"
			msg_warn="${msg_warn}\n=> Partition table is going to be recreated as GPT!\n"
			((msg_size+=4))
			((disk_change_needed+=1))
			cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo 'label: gpt' | sfdisk /dev/${TARGET_DISK_SET}
EOF
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
sfdisk -d /dev/${TARGET_DISK_SET} | grep -vE "^\/dev\/${TARGET_DISK_SET}" > $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

########
# BOOT
########
		first_sector="$(sfdisk -d /dev/${TARGET_DISK_SET} | grep "first-lba" | sed 's/^.*: //')"
		(( part_sectors=${TARGET_BOOT_PARTSZ_SET}*${sectors_in_kib}*1024*1024 ))
		# Warn, if BOOT partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${TARGET_DISK_SET}1" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}1) boot partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if BOOT partition NOT EFI: 
			check_part_type "EFI" "boot"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}1) boot partition - Not EFI type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if BOOT partition NOT SIZED: 
				check_part_size "boot"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}1) Boot partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${TARGET_DISK_SET}1 : size= ${part_sectors}, type=${PART_TYPE_EFI}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

#######
# LOG
#######
		(( first_sector+=part_sectors ))
		(( part_sectors=${TARGET_LOG_PARTSZ_SET}*${sectors_in_kib}*1024*1024 ))
		# Warn, if LOG partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${TARGET_DISK_SET}2" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}2) log partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if LOG partition NOT LINUX: 
			check_part_type "Linux" "log"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}2) log partition - Not Linux type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if LOG partition NOT SIZED: 
				check_part_size "log"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}2) log partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${TARGET_DISK_SET}2 : size= ${part_sectors}, type=${PART_TYPE_LINUX}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

#########
# ROOTA
#########
		(( first_sector+=part_sectors ))
		(( part_sectors=${TARGET_ROOTA_PARTSZ_SET}*${sectors_in_kib}*1024*1024 ))
		# Warn, if ROOTA partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${TARGET_DISK_SET}3" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}3) rootA partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if ROOTA partition NOT LINUX: 
			check_part_type "Linux" "rootA"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}3) rootA partition - Not Linux type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if ROOTA partition NOT SIZED: 
				check_part_size "rootA"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}3) rootA partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${TARGET_DISK_SET}3 : size= ${part_sectors}, type=${PART_TYPE_LINUX}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

#########
# ROOTB
#########
		(( first_sector+=part_sectors ))
		(( part_sectors=${TARGET_ROOTB_PARTSZ_SET}*${sectors_in_kib}*1024*1024 ))
		# Warn, if ROOTB partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${TARGET_DISK_SET}4" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}4) rootB partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if ROOTB partition NOT LINUX: 
			check_part_type "Linux" "rootB"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}4) rootB partition - Not Linux type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if ROOTB partition NOT SIZED: 
				check_part_size "rootB"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${TARGET_DISK_SET}4) rootB partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${TARGET_DISK_SET}4 : size= ${part_sectors}, type=${PART_TYPE_LINUX}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

		if [ $disk_change_needed -ne 0 ]; then
			msg_fdisk="${msg_fdisk}\n-----------------------------------"
			msg_warn="${msg_warn}-----------------------------------\n"
			msg_warn="${msg_warn}\n=> Partition table is going to be changed and ALL TARGET DATA LOST!\n"
			((msg_size+=5))
			cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
sfdisk /dev/${TARGET_DISK_SET} < $U2UP_TARGET_DISK_SFDISK_DUMP
EOF
		else
			rm -f ${U2UP_TARGET_DISK_SFDISK_BASH}
			msg_warn="${msg_warn}\n-----------------------------------\n"
			msg_warn="${msg_warn}\n=> Partition table is NOT going to be changed!\n"
			((msg_size+=5))
		fi
		if [ $disk_change_needed -ne 0 ]; then
			if [ "x${action_name}" != "xInstallation" ]; then
				msg_warn="${msg_warn}\nDo you really want to continue?"
				((msg_size+=3))
				display_yesno "${action_name} warning" "${msg_fdisk}${msg_warn}" $msg_size
				if [ $? -eq 0 ]; then
					#Yes
					return 0
				else
					#No
					display_result "${action_name}" "${action_name} interrupted!"
					return 1	
				fi
			else
				msg_warn="${msg_warn}\n${action_name} interrupted?"
				((msg_size+=3))
				display_msg "${action_name} warning" "${msg_fdisk}${msg_warn}" $msg_size
				return 1 # To skip additional "success" message!
			fi
		else
			if [ "x${action_name}" != "xInstallation" ]; then
				display_msg "${action_name} notice" "${msg_fdisk}${msg_warn}" $msg_size
				return 1 # To skip additional "success" message!
			else
				msg_warn="${msg_warn}\n=> You are about to install new system on disk partition:"
				msg_warn="${msg_warn}\n=> [${TARGET_PART_SET} - ${root_part_label}]\n"
				msg_warn="${msg_warn}\nDo you really want to continue?"
				((msg_size+=5))
				display_yesno "${action_name} warning" "${msg_fdisk}${msg_warn}" $msg_size
				if [ $? -eq 0 ]; then
					#Yes
					return 0
				else
					#No
					display_result "${action_name}" "${action_name} interrupted!"
					return 1	
				fi
			fi
		fi
	else
		check_target_disk_configuration
	fi
}

proceed_target_repartition() {
	loacal rv=1
	if [ -f "${U2UP_TARGET_DISK_SFDISK_BASH}" ]; then
		echo "Re-partitioning disk:" >&2
		bash ${U2UP_TARGET_DISK_SFDISK_BASH}
		if [ $? -ne 0 ]; then
			echo "press enter to continue..." >&2
			read
			display_result "Re-partition" "Failed to re-partition disk!"
			return 1
		fi
		sfdisk -V /dev/${TARGET_DISK_SET}
		if [ $? -ne 0 ]; then
			echo "press enter to continue..." >&2
			read
			display_result "Re-partition" "Failed to re-partition disk!"
			return 1
		fi
	fi
	echo "press enter to continue..." >&2
	read
	display_result "Re-partition" "Re-partition successfully finished!"
}

execute_target_repartition() {
	local rv=0
	check_target_disk_configuration
	rv=$?
	if [ $rv -eq 0 ]; then
		check_current_target_disk_setup "Re-partition"
		rv=$?
		if [ $rv -eq 0 ]; then
			proceed_target_repartition
			rv=$?
		fi
	fi
	return $rv
}

display_target_partsizes_submenu() {
	local current_set=""
	local current_item=""
	local target_disk_current=""
	local target_boot_partsz_current=${1:-2}
	local target_log_partsz_current=${2:-5}
	local target_rootA_partsz_current=${3:-20}
	local target_rootB_partsz_current=${4:-20}
	local rv=1

	check_target_disk_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	local target_disk_current=$TARGET_DISK_SET

	while true; do
		exec 3>&1
		selection=$(IFS='|'; \
		dialog \
			--backtitle "${U2UP_BACKTITLE}" \
			--title "Target partitions" \
			--clear \
			--default-item "$current_item" \
			--cancel-label "Cancel" \
			--extra-label "Resize" \
			--cr-wrap \
			--inputmenu $(fdisk -l /dev/${target_disk_current})"\n\nPlease select:" $HEIGHT 0 15 \
			"boot  [/dev/${target_disk_current}1] (GiB):" ${target_boot_partsz_current} \
			"log   [/dev/${target_disk_current}2] (GiB):" ${target_log_partsz_current} \
			"rootA [/dev/${target_disk_current}3] (GiB):" ${target_rootA_partsz_current} \
			"rootB [/dev/${target_disk_current}4] (GiB):" ${target_rootB_partsz_current} \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-

		case $exit_status in
		$DIALOG_CANCEL|$DIALOG_ESC)
			clear
			echo "Return from submenu." >&2
			return 1
			;;
		esac

		current_item="$(get_item_selection $selection)"
		current_set="$(store_target_partsize_selection ${U2UP_CONF_DIR} $selection)"
		if [ -n "$current_set" ]; then
			#Resize pressed: set new dialog values
			eval $current_set
		else
			#Ok
			store_target_partsize_selection ${U2UP_CONF_DIR} "boot :${target_boot_partsz_current}"
			store_target_partsize_selection ${U2UP_CONF_DIR} "log :${target_log_partsz_current}"
			store_target_partsize_selection ${U2UP_CONF_DIR} "rootA :${target_rootA_partsz_current}"
			store_target_partsize_selection ${U2UP_CONF_DIR} "rootB :${target_rootB_partsz_current}"
			execute_target_repartition
			return $?
		fi
	done
}

display_target_hostname_submenu() {
	local current_set=""
	local current_item=""
	local target_hostname_current=${1:-"$(hostname)"}
	local rv=0

	while true; do
		exec 3>&1
		selection=$(IFS='|'; \
		dialog \
			--backtitle "${U2UP_BACKTITLE}" \
			--title "Hostname configuration [${target_hostname_current}]" \
			--clear \
			--default-item "$current_item" \
			--cancel-label "Cancel" \
			--extra-label "Change" \
			--cr-wrap \
			--inputmenu "\nPlease set:" $HEIGHT 0 6 \
			"Hostname:" ${target_hostname_current} \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-

		case $exit_status in
		$DIALOG_CANCEL|$DIALOG_ESC)
			clear
			echo "Return from submenu." >&2
			return 1
			;;
		esac

		current_item="$(get_item_selection $selection)"
		current_set="$(store_target_hostname_selection ${U2UP_CONF_DIR} $selection)"
		if [ -n "$current_set" ]; then
			#Resize pressed: set new dialog values
			eval $current_set
		else
			#Ok
			store_target_hostname_selection ${U2UP_CONF_DIR} "Hostname: ${target_hostname_current}"
			(( rv+=$? ))
			return $rv
		fi
	done
}

display_target_admin_submenu() {
	local current_set=""
	local current_item=""
	local target_admin_name_current=${1:-"admin"}
	local rv=0

	while true; do
		exec 3>&1
		selection=$(IFS='|'; \
		dialog \
			--backtitle "${U2UP_BACKTITLE}" \
			--title "Hostname configuration [${target_admin_name_current}]" \
			--clear \
			--default-item "$current_item" \
			--cancel-label "Cancel" \
			--extra-label "Change" \
			--cr-wrap \
			--inputmenu "\nPlease set:" $HEIGHT 0 6 \
			"Admin name:" ${target_admin_name_current} \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-

		case $exit_status in
		$DIALOG_CANCEL|$DIALOG_ESC)
			clear
			echo "Return from submenu." >&2
			return 1
			;;
		esac

		current_item="$(get_item_selection $selection)"
		current_set="$(store_target_admin_selection ${U2UP_CONF_DIR} $selection)"
		if [ -n "$current_set" ]; then
			#Resize pressed: set new dialog values
			eval $current_set
		else
			#Ok
			store_target_admin_selection ${U2UP_CONF_DIR} "Admin name: ${target_admin_name_current}"
			(( rv+=$? ))
			return $rv
		fi
	done
}

execute_net_reconfiguration() {
	local TARGET_ROOT_PATH_PREFIX=$1
	local NET_INTERNAL_IFNAME=""
	local NET_INTERNAL_ADDR_MASK=""
	local NET_INTERNAL_GW=""
	local NET_DNS=""
	local NET_DOMAINS=""
	local rv=1
	if [ -z "$TARGET_ROOT_PATH_PREFIX" ]; then
		return $rv
	fi
	check_network_configuration
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	if [ -f "${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}
	fi
	cat > ${TARGET_ROOT_PATH_PREFIX}etc/systemd/network/10-internal-static.network << EOF
[Match]
Name=${NET_INTERNAL_IFNAME_SET}

[Network]
Address=${NET_INTERNAL_ADDR_MASK_SET}
Gateway=${NET_INTERNAL_GW_SET}
DNS=${NET_DNS_SET}
Domains=${NET_DOMAINS_SET}
EOF
	return $rv
}

display_install_repo_config_submenu() {
	local current_set=""
	local current_item=""
	local install_repo_base_url_current=${1:-"http://192.168.1.113:5678"}
	local rv=1

	check_install_repo_config_set
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi

	while true; do
		exec 3>&1
		selection=$(IFS='|'; \
		dialog \
			--backtitle "${U2UP_BACKTITLE}" \
			--title "Installation packages repo" \
			--clear \
			--default-item "$current_item" \
			--cancel-label "Cancel" \
			--extra-label "Change" \
			--cr-wrap \
			--inputmenu "\nPlease set:" $HEIGHT 0 12 \
			"Base URL:" ${install_repo_base_url_current} \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-

		case $exit_status in
		$DIALOG_CANCEL|$DIALOG_ESC)
			clear
			echo "Return from submenu." >&2
			return 1
			;;
		esac

		current_item="$(get_item_selection $selection)"
		current_set="$(store_install_repo_selection ${U2UP_CONF_DIR} $selection)"
		if [ -n "$current_set" ]; then
			#Resize pressed: set new dialog values
			eval $current_set
		else
			#Ok
			store_install_repo_selection ${U2UP_CONF_DIR} "Base URL: ${install_repo_base_url_current}"
			(( rv+=$? ))
			return $rv
		fi
	done
}

check_create_filesystems() {
	local TARGET_DISK_SET=""
	local TARGET_PART_SET=""
	local fstype=""
	local rv=1

	if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	fi
	if [ -z "$TARGET_DISK_SET" ] || [ -z "TARGET_PART_SET" ]; then
		return $rv
	fi
	# Installation partition:
	echo "Allways re-create EXT4 filesystem on installation partition /dev/$TARGET_PART_SET:" >&2
	umount -f /mnt >&2
	mkfs.ext4 -F /dev/$TARGET_PART_SET >&2
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo -e "OK!\n" >&2
	# Boot partition:
	echo "Check / re-create VFAT filesystem on \"boot\" partition /dev/${TARGET_DISK_SET}1:" >&2
	fstype="$(lsblk -fr /dev/${TARGET_DISK_SET}1 | grep -v "NAME" | sed 's/[a-z,0-9]* //' | sed 's/ .*//')"
	if [ -z "$fstype" ] || [ "$fstype" != "vfat" ]; then
		echo "Recreate:" >&2
		mkfs.vfat -F /dev/${TARGET_DISK_SET}1 >&2
		rv=$?
		if [ $rv -ne 0 ]; then
			return $rv
		fi
	fi
	echo -e "OK!\n" >&2
	# Log partition:
	echo "Check / re-create EXT4 filesystem on \"log\" partition /dev/${TARGET_DISK_SET}1:" >&2
	fstype="$(lsblk -fr /dev/${TARGET_DISK_SET}2 | grep -v "NAME" | sed 's/[a-z,0-9]* //' | sed 's/ .*//')"
	if [ -z "$fstype" ] || [ "$fstype" != "ext4" ]; then
		echo "Recreate:" >&2
		mkfs.ext4 -F /dev/${TARGET_DISK_SET}2 >&2
		rv=$?
		if [ $rv -ne 0 ]; then
			return $rv
		fi
	fi
	echo -e "OK!\n" >&2
	# RootA partition:
	echo "Check / re-create EXT4 filesystem on \"rootA\" partition /dev/${TARGET_DISK_SET}1:" >&2
	fstype="$(lsblk -fr /dev/${TARGET_DISK_SET}3 | grep -v "NAME" | sed 's/[a-z,0-9]* //' | sed 's/ .*//')"
	if [ -z "$fstype" ] || [ "$fstype" != "ext4" ]; then
		echo "Recreate:" >&2
		mkfs.ext4 -F /dev/${TARGET_DISK_SET}3 >&2
		rv=$?
		if [ $rv -ne 0 ]; then
			return $rv
		fi
	fi
	echo -e "OK!\n" >&2
	# RootB partition:
	echo "Check / re-create EXT4 filesystem on \"rootB\" partition /dev/${TARGET_DISK_SET}1:" >&2
	fstype="$(lsblk -fr /dev/${TARGET_DISK_SET}4 | grep -v "NAME" | sed 's/[a-z,0-9]* //' | sed 's/ .*//')"
	if [ -z "$fstype" ] || [ "$fstype" != "ext4" ]; then
		echo "Recreate:" >&2
		mkfs.ext4 -F /dev/${TARGET_DISK_SET}4 >&2
		rv=$?
		if [ $rv -ne 0 ]; then
			return $rv
		fi
	fi
	echo -e "OK!\n" >&2
	rv=0
	return $rv
}


populate_root_filesystem() {
	local TARGET_DISK_SET=""
	local TARGET_PART_SET=""
	local root_part_suffix=""
	local root_part_uuid=""
	local rv=1

	if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	fi
	if [ -z "$TARGET_DISK_SET" ] || [ -z "TARGET_PART_SET" ]; then
		return $rv
	fi
	root_part_uuid="$(lsblk -ir -o NAME,PARTUUID /dev/$TARGET_PART_SET | grep -v "NAME" | sed 's/[a-z,0-9]* //')"
	if [ -z "$root_part_uuid" ]; then
		return $rv
	fi
	if [ "${TARGET_PART_SET}" = "${TARGET_DISK_SET}3" ]; then
		root_part_suffix="A"
	elif [ "${TARGET_PART_SET}" = "${TARGET_DISK_SET}4" ]; then
		root_part_suffix="B"
	else
		return $rv
	fi

	echo "Mounting root filesystem:" >&2
	umount -f /mnt >&2
	mount /dev/$TARGET_PART_SET /mnt >&2
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Extracting root filesystem archive:" >&2
	tar xvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} -O ${U2UP_FS_IMAGE_ARCHIVE}-${MACHINE}.tar.gz | tar xz -C /mnt >&2
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
#	echo "Extracting kernel modules archive:" >&2
#	tar xvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} -O ${U2UP_KERNEL_MODULES_IMAGE_ARCHIVE}-${MACHINE}.tgz | tar xz -C /mnt >&2
#	rv=$?
#	if [ $rv -ne 0 ]; then
#		return $rv
#	fi
	echo "Populate \"u2up-config.d\" of the installed system:" >&2
	populate_u2up_configurations "/mnt"
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Configure target keyboard mapping:" >&2
	enable_keymap_selection 1 "/mnt"
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Configure \"fstab\" for common boot partition:" >&2
	echo "/dev/${TARGET_DISK_SET}1 /boot vfat umask=0077 0 1" >> /mnt/etc/fstab
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Configure \"fstab\" for common logging partition:" >&2
	echo "/dev/${TARGET_DISK_SET}2 /var/log ext4 errors=remount-ro 0 1" >> /mnt/etc/fstab
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Done configuring target disk and partitions:" >&2
	set_target_done_for /mnt/${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE} 1
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Configure \"internal network\" of the installed system:" >&2
	execute_net_reconfiguration "/mnt/"
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Mounting boot filesystem:" >&2
	umount -f /mnt >&2
	mount /dev/${TARGET_DISK_SET}1 /mnt >&2
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Prepare boot images:" >&2
	mkdir -p /mnt/EFI/BOOT
	mkdir -p /mnt/loader/entries
	tar xvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} --no-same-owner --no-same-permissions -C /mnt ${U2UP_KERNEL_IMAGE}-${MACHINE}.bin >&2
	((rv+=$?))
	mv /mnt/${U2UP_KERNEL_IMAGE}-${MACHINE}.bin /mnt/bzImage${root_part_suffix} >&2
	((rv+=$?))
	tar xvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} --no-same-owner --no-same-permissions -C /mnt ${U2UP_INITRD_IMAGE}.cpio >&2
	((rv+=$?))
	mv /mnt/${U2UP_INITRD_IMAGE}.cpio /mnt/microcode${root_part_suffix}.cpio >&2
	((rv+=$?))
	if [ ! -f "/mnt/EFI/BOOT/bootx64.efi" ]; then
		tar xvf ${U2UP_IMAGES_BUNDLE_ARCHIVE} --no-same-owner --no-same-permissions -C /mnt/EFI/BOOT systemd-${U2UP_EFI_FALLBACK_IMAGE} >&2
		((rv+=$?))
		mv /mnt/EFI/BOOT/systemd-${U2UP_EFI_FALLBACK_IMAGE} /mnt/EFI/BOOT/${U2UP_EFI_FALLBACK_IMAGE} >&2
		((rv+=$?))
	fi
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Create new boot  \"${root_part_label}\" menu:" >&2
	source ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}
	echo "title ${root_part_label} (${U2UP_ROOTFS_DTS})" > /mnt/loader/entries/${root_part_label}.conf
	((rv+=$?))
	echo "linux /bzImage${root_part_suffix}" >> /mnt/loader/entries/${root_part_label}.conf
	((rv+=$?))
	echo "options label=${root_part_label} root=PARTUUID=${root_part_uuid} rootwait rootfstype=ext4 console=tty0 ttyprintk.tioccons=1" >> /mnt/loader/entries/${root_part_label}.conf
	((rv+=$?))
	echo "initrd /microcode${root_part_suffix}.cpio" >> /mnt/loader/entries/${root_part_label}.conf
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	echo "Configure default boot:" >&2
	echo "default ${root_part_label}" > /mnt/loader/loader.conf
	((rv+=$?))
	echo "timeout 5" >> /mnt/loader/loader.conf
	((rv+=$?))
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	return $rv
}

proceed_target_install() {
	local rv=1

	check_create_filesystems
	rv=$?
	if [ $rv -ne 0 ]; then
		echo "press enter to continue..." >&2
		read
		display_result "Installation" "Failed to check / create filesystems!"
		return $rv
	fi

	populate_root_filesystem
	rv=$?
	if [ $rv -ne 0 ]; then
		echo "press enter to continue..." >&2
		read
		display_result "Installation" "Failed to populate root filesystem!"
		return $rv
	fi

	echo "press enter to continue..." >&2
	read
	display_yesno "Installation" \
"Installation successfully finished!\n\n\
To reboot into new target installation, remove the installation media during the system reset!\n\n\
Do you wish to reboot into new target installation now?" 10
	rv=$?
	if [ $rv -eq 0 ]; then
		#Yes
		reboot
		exit 0
	fi
	return $rv
}

execute_target_install() {
	check_target_configurations
	if [ $? -eq 0 ]; then
		check_current_target_disk_setup "Installation"
		if [ $? -eq 0 ]; then
			proceed_target_install
		fi
	fi
}

main_loop () {
	local rv=1
	local current_tag='1'
	local root_part_label=""
	local net_internal_mac=""
	local KEYMAP_SET=""
	local TARGET_DISK_SET=""
	local TARGET_PART_SET=""
	local TARGET_BOOT_PARTSZ_SET=""
	local TARGET_LOG_PARTSZ_SET=""
	local TARGET_ROOTA_PARTSZ_SET=""
	local TARGET_ROOTB_PARTSZ_SET=""
	local TARGET_HOSTNAME_SET=""
	local TARGET_ADMIN_NAME_SET=""
	local NET_INTERNAL_IFNAME=""
	local NET_INTERNAL_ADDR_MASK=""
	local NET_INTERNAL_GW=""
	local NET_DNS=""
	local NET_DOMAINS=""
	local INSTALL_REPO_BASE_URL=""

	while true; do
		if [ -f "${U2UP_CONF_DIR}/${U2UP_KEYMAP_CONF_FILE}" ]; then
			source ${U2UP_CONF_DIR}/${U2UP_KEYMAP_CONF_FILE}
		fi
		if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
			source ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
		fi
		root_part_label="$(get_root_label ${TARGET_DISK_SET} ${TARGET_PART_SET})"
		if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_HOSTNAME_CONF_FILE}" ]; then
			source ${U2UP_CONF_DIR}/${U2UP_TARGET_HOSTNAME_CONF_FILE}
		fi
		if [ -f "${U2UP_CONF_DIR}/${U2UP_TARGET_ADMIN_CONF_FILE}" ]; then
			source ${U2UP_CONF_DIR}/${U2UP_TARGET_ADMIN_CONF_FILE}
		fi
		if [ -f "${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}" ]; then
			source ${U2UP_CONF_DIR}/${U2UP_NETWORK_CONF_FILE}
		fi
		net_internal_mac=""
		if [ -n "${NET_INTERNAL_IFNAME_SET}" ]; then
			net_internal_mac="$(ip link show dev $NET_INTERNAL_IFNAME_SET | grep "link\/ether" | sed 's/ *link\/ether *//' | sed 's/ .*//')"
		fi
		if [ -f "${U2UP_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}" ]; then
			source ${U2UP_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}
		fi

		exec 3>&1
		selection=$(dialog \
			--backtitle "${U2UP_BACKTITLE}" \
			--title "Menu" \
			--clear \
			--cancel-label "Exit" \
			--default-item $current_tag \
			--menu "Please select:" $HEIGHT $WIDTH 10 \
			"1" "Keyboard mapping [${KEYMAP_SET}]" \
			"2" "Target disk [${TARGET_DISK_SET}]" \
			"3" "Disk partitions \
[boot:${TARGET_BOOT_PARTSZ_SET}G] \
[log:${TARGET_LOG_PARTSZ_SET}G] \
[rootA:${TARGET_ROOTA_PARTSZ_SET}G] \
[rootB:${TARGET_ROOTB_PARTSZ_SET}G]" \
			"4" "Hostname [${TARGET_HOSTNAME_SET}]" \
			"5" "Administrator [${TARGET_ADMIN_NAME_SET}]" \
			"6" "Network internal interface [${NET_INTERNAL_IFNAME_SET} - ${net_internal_mac}]" \
			"7" "Static network configuration [${NET_INTERNAL_ADDR_MASK_SET}]" \
			"8" "Installation packages repo [${INSTALL_REPO_BASE_URL_SET}]" \
			"9" "Installation partition [${TARGET_PART_SET} - ${root_part_label}]" \
			"10" "Install (${U2UP_ROOTFS_DTS})" \
		2>&1 1>&3)
		exit_status=$?
		exec 3>&-

		case $exit_status in
		$DIALOG_CANCEL)
			clear
			echo "Program terminated." >&2
			exit
			;;
		$DIALOG_ESC)
			clear
			echo "Program aborted." >&2
			exit 1
			;;
		esac

		current_tag=$selection
		case $selection in
		0)
			clear
			echo "Program terminated." >&2
			;;
		1)
			display_keymap_submenu \
				$KEYMAP_SET
			;;
		2)
			display_target_disk_submenu \
				$TARGET_DISK_SET
			;;
		3)
			local target_boot_partsz_old=$TARGET_BOOT_PARTSZ_SET
			local target_log_partsz_old=$TARGET_LOG_PARTSZ_SET
			local target_rootA_partsz_old=$TARGET_ROOTA_PARTSZ_SET
			local target_rootB_partsz_old=$TARGET_ROOTB_PARTSZ_SET
			display_target_partsizes_submenu \
				$TARGET_BOOT_PARTSZ_SET \
				$TARGET_LOG_PARTSZ_SET \
				$TARGET_ROOTA_PARTSZ_SET \
				$TARGET_ROOTB_PARTSZ_SET
			rv=$?
			if [ $rv -ne 0 ]; then
				# Restore old partition sizes
				store_target_partsize_selection ${U2UP_CONF_DIR} "boot :${target_boot_partsz_old}"
				store_target_partsize_selection ${U2UP_CONF_DIR} "log :${target_log_partsz_old}"
				store_target_partsize_selection ${U2UP_CONF_DIR} "rootA :${target_rootA_partsz_old}"
				store_target_partsize_selection ${U2UP_CONF_DIR} "rootB :${target_rootB_partsz_old}"
			fi
			;;
		4)
			local target_hostname_old=$TARGET_HOSTNAME_SET
			display_target_hostname_submenu \
				$TARGET_HOSTNAME_SET
			;;
		5)
			local target_admin_name_old=$TARGET_ADMIN_NAME_SET
			display_target_admin_submenu \
				$TARGET_ADMIN_NAME_SET
			;;
		6)
			display_net_internal_ifname_submenu \
				$NET_INTERNAL_IFNAME_SET
			;;
		7)
			local net_internal_addr_mask_old=$NET_INTERNAL_ADDR_MASK_SET
			local net_internal_gw_old=$NET_INTERNAL_GW_SET
			local net_dns_old=$NET_DNS_SET
			local net_domains_old=$NET_DOMAINS_SET
			display_net_config_submenu \
				$U2UP_CONF_DIR \
				$NET_INTERNAL_ADDR_MASK_SET \
				$NET_INTERNAL_GW_SET \
				$NET_DNS_SET \
				$NET_DOMAINS_SET
			rv=$?
			if [ $rv -ne 0 ]; then
				# Restore old network configuration
				if [ -n "${net_internal_addr_mask_old}" ]; then
					store_net_config_selection ${U2UP_CONF_DIR} "IP address/mask: ${net_internal_addr_mask_old}"
				fi
				if [ -n "${net_internal_gw_old}" ]; then
					store_net_config_selection ${U2UP_CONF_DIR} "IP gateway: ${net_internal_gw_old}"
				fi
				if [ -n "${net_dns_old}" ]; then
					store_net_config_selection ${U2UP_CONF_DIR} "DNS: ${net_dns_old}"
				fi
				if [ -n "${net_domains_old}" ]; then
					store_net_config_selection ${U2UP_CONF_DIR} "Domains: ${net_domains_old}"
				fi
			else
				execute_net_reconfiguration "/"
			fi
			;;
		8)
			local install_repo_base_url_old=$INSTALL_REPO_BASE_URL_SET
			display_install_repo_config_submenu \
				$INSTALL_REPO_BASE_URL_SET
			rv=$?
			if [ $rv -ne 0 ]; then
				# Restore old installation packages repo configuration
				if [ -n "${install_repo_base_url_old}" ]; then
					store_install_repo_selection ${U2UP_CONF_DIR} "Base URL: ${install_repo_base_url_old}"
				fi
			fi
			;;
		9)
			display_target_part_submenu \
				$TARGET_DISK_SET \
				$TARGET_PART_SET
			;;
		10)
			execute_target_install
			;;
		esac
	done
}

# Call main function:
main_loop

