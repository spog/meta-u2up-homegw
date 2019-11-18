#!/bin/bash
#
# A dialog menu based u2up-homegw-installer program, used
# to make new installation to the inactive partition.
#
trap "echo 'Exited: '${0} >&2; exec 2>&-" EXIT
exec 2> >(logger -s -t $(basename $0))
echo >&2
echo "Started: ${0}" >&2
#set -x

U2UP_INSTALL_BASH_LIB="${HOME}/u2up-install-bash-lib-local"
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	U2UP_INSTALL_BASH_LIB="/lib/u2up/u2up-install-bash-lib"
else
	echo "WARNING! Using (bash-lib-local) script!" >&2
fi
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	echo "Program terminated (missing: ${U2UP_INSTALL_BASH_LIB})!" >&2
	exit 1
fi
if [ -z "${U2UP_INSTALL_BASH_LIB_SOURCED}" ]; then
	source ${U2UP_INSTALL_BASH_LIB}
fi
exit_handler() {
	echo "Unmounting \"${U2UP_INSTALL_ROOT_MNT}\"..." >&2
	umount -f ${U2UP_INSTALL_ROOT_MNT}
	echo "Unmounting \"${U2UP_TMP_BOOT_DIR}\"..." >&2
	umount -f ${U2UP_TMP_BOOT_DIR}
	echo 'Exited: '${0} >&2
	exec 2>&-
}
trap exit_handler EXIT
U2UP_INSTALL_DIALOG_LIB="${HOME}/u2up-install-dialog-lib-local"
if [ ! -f "${U2UP_INSTALL_DIALOG_LIB}" ]; then
	U2UP_INSTALL_DIALOG_LIB="/lib/u2up/u2up-install-dialog-lib"
else
	echo "WARNING! Using (dialog-lib-local) script!" >&2
fi
if [ ! -f "${U2UP_INSTALL_DIALOG_LIB}" ]; then
	echo "Program terminated (missing: ${U2UP_INSTALL_DIALOG_LIB})!" >&2
	exit 1
fi
if [ -z "${U2UP_INSTALL_DIALOG_LIB_SOURCED}" ]; then
	source ${U2UP_INSTALL_DIALOG_LIB}
fi

U2UP_CURRENT_TARGET_DISK=$(get_current_target_disk)
U2UP_CURRENT_TARGET_PART=$(get_current_target_part)
current_root_part_label="$(get_root_label ${U2UP_CURRENT_TARGET_DISK} ${U2UP_CURRENT_TARGET_PART})"
if [ -z "${current_root_part_label}" ]; then
	echo "Program terminated (unrecognised current root disk and partition: disk=\"${U2UP_CURRENT_TARGET_DISK}\", part=\"${U2UP_CURRENT_TARGET_PART}\")!" >&2
	exit 1
fi
current_root_part_label_suffix="$(get_root_label_suffix_from_label ${current_root_part_label})"
if [ -z "${current_root_part_label_suffix}" ]; then
	echo "Program terminated (unrecognised current root partition label: disk=\"${U2UP_CURRENT_TARGET_DISK}\", part=\"${U2UP_CURRENT_TARGET_PART}\")!" >&2
	exit 1
fi

default_boot_label="$(get_default_boot_label ${U2UP_CURRENT_TARGET_DISK})"
if [ -z "${default_boot_label}" ]; then
	echo "Program terminated (unrecognised current boot setup)!" >&2
	exit 1
fi

U2UP_INSTALL_CONF_DIR="/var/lib/u2up-conf.d"
if [ ! -d "${U2UP_INSTALL_CONF_DIR}" ]; then
	rm -rf $U2UP_INSTALL_CONF_DIR
	mkdir -p $U2UP_INSTALL_CONF_DIR
	prepare_u2up_upgrade_configuration ${U2UP_INSTALL_CONF_DIR}
	if [ $? -ne 0 ]; then
		echo "Program terminated (failed to prepare upgrade configuration in: ${U2UP_INSTALL_CONF_DIR})!" >&2
		exit 1
	fi
fi

#if [ ! -f "${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}" ]; then
#	echo "Program terminated (missing: ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE})!" >&2
#	exit 1
#fi
#source ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}
#U2UP_CURRENT_ROOTFS_DATETIME=${u2up_ROOTFS_DATETIME}
DIALOG_CANCEL=1
DIALOG_ESC=255
HEIGHT=0
WIDTH=0
#U2UP_BACKTITLE="U2UP-HOMEGW installer - ${current_root_part_label} (${U2UP_CURRENT_ROOTFS_DATETIME}):"

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
	2>&1 >&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	save_u2up_keymap_selection $selection ${U2UP_INSTALL_CONF_DIR}
	save_u2up_keymap_selection $selection
	rv=$?
	if [ $rv -eq 0 ]; then
		enable_u2up_keymap_selection
	fi
}

display_target_disk_submenu() {
	local target_disk_to_display=$1
	local radiolist=""
	local tag="start_tag"

	radiolist=$(lsblk -ir -o NAME,SIZE,MODEL | sed 's/x20//g' | sed 's/\\//g' | while read line; do
		set -- $line
		if [ -n "$1" ] && [ "$1" != "NAME" ] && [[ "$1" != "$tag"* ]]; then
			tag=$1
			shift
			if [ -n "$target_disk_to_display" ] && [ "$tag" == "$target_disk_to_display" ]; then
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
	2>&1 >&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	save_u2up_target_disk_selection $selection ${U2UP_INSTALL_CONF_DIR}
}

display_target_part_submenu() {
	local target_disk_to_set=$1
	local target_part_to_set=$2
	local radiolist=""
	local tag="start_tag"

	radiolist=$(lsblk -ir -o NAME,SIZE,PARTUUID | grep -v "${U2UP_CURRENT_TARGET_PART}" | grep -E "(${target_disk_to_set}3|${target_disk_to_set}4)" | while read line; do
		set -- $line
		if [ -n "$1" ] && [ "$1" != "NAME" ] && [[ "$1" != "$tag"* ]]; then
			tag=$1
			shift
			if [ -n "$target_part_to_set" ] && [ "$tag" == "$target_part_to_set" ]; then
				echo -n "${tag}|"$@"|on|"
			else
				echo -n "${tag}|"$@"|off|"
			fi
		fi
	done)

	if [ -z "$radiolist" ]; then
		return 1
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
	2>&1 >&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	save_u2up_target_part_selection $selection ${U2UP_INSTALL_CONF_DIR}
}

display_target_boot_submenu() {
	local radiolist=""
	local tag="start_tag"

	radiolist=$(ls ${U2UP_TMP_BOOT_DIR}/loader/entries/ | sed 's/\.conf//g' | while read line; do
		tag=$(get_boot_label $line)
		if [ -n "$default_boot_label" ] && [ "$tag" == "$default_boot_label" ]; then
			echo -n "${tag}|"$@"|on|"
		else
			echo -n "${tag}|"$@"|off|"
		fi
	done)

	if [ -z "$radiolist" ]; then
		return 1
	fi

	exec 3>&1
	selection=$(IFS='|'; \
	dialog \
		--backtitle "${U2UP_BACKTITLE}" \
		--title "Default boot selection" \
		--clear \
		--cancel-label "Cancel" \
		--radiolist "Please select:" $HEIGHT $WIDTH 0 \
		${radiolist} \
	2>&1 >&3)
	exit_status=$?
	exec 3>&-

	case $exit_status in
	$DIALOG_CANCEL|$DIALOG_ESC)
		clear
		echo "Return from submenu." >&2
		return 0
		;;
	esac

	set_default_boot $selection
}

check_target_disk_set() {
	if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		u2up_TARGET_DISK=""
	fi
	if [ -z "$u2up_TARGET_DISK" ]; then
		display_result "Target disk check" "Please select your target disk for the installation!"
		return 1
	fi
}

check_install_repo_config_set() {
	if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}" ]; then
		source ${U2UP_INSTALL_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}
	else
		u2up_INSTALL_REPO_BASE_URL=""
	fi
	if [ -z "$u2up_INSTALL_REPO_BASE_URL" ]; then
		display_result "Installation REPO BASE URL check" "Please set your REPO BASE URL!"
		return 1
	fi
}

check_target_part_set() {
	if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		u2up_TARGET_PART=""
	fi
	if [ -z "$u2up_TARGET_PART" ]; then
		display_result "Target partition check" "Please select your target partition for the installation!"
		return 1
	fi
}

check_target_part_sizes_set() {
	if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		u2up_TARGET_BOOT_PARTSZ=""
	fi
	if \
		[ -z "$u2up_TARGET_BOOT_PARTSZ" ] || \
		[ -z "$u2up_TARGET_LOG_PARTSZ" ] || \
		[ -z "$u2up_TARGET_ROOTA_PARTSZ" ] || \
		[ -z "$u2up_TARGET_ROOTB_PARTSZ" ];
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
		PART_NAME="${u2up_TARGET_DISK}1"
		;;
	log)
		PART_NAME="${u2up_TARGET_DISK}2"
		;;
	rootA)
		PART_NAME="${u2up_TARGET_DISK}3"
		;;
	rootB)
		PART_NAME="${u2up_TARGET_DISK}4"
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
	(( sectors_in_kib=1024/$(cat /sys/block/${u2up_TARGET_DISK}/queue/hw_sector_size) ))

	if [ $sectors_in_kib -le 0 ]; then
		retrn 1
	fi
	case $1 in
	boot)
		PART_NAME="${u2up_TARGET_DISK}1"
		PART_SIZE="${u2up_TARGET_BOOT_PARTSZ}"
		;;
	log)
		PART_NAME="${u2up_TARGET_DISK}2"
		PART_SIZE="${u2up_TARGET_LOG_PARTSZ}"
		;;
	rootA)
		PART_NAME="${u2up_TARGET_DISK}3"
		PART_SIZE="${u2up_TARGET_ROOTA_PARTSZ}"
		;;
	rootB)
		PART_NAME="${u2up_TARGET_DISK}4"
		PART_SIZE="${u2up_TARGET_ROOTB_PARTSZ}"
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
	local msg_fdisk="$(fdisk -l /dev/${u2up_TARGET_DISK})\n"
	local msg_size=17
	local disk_change_needed=0
	local first_sector=0
	local sectors_in_kib=0
	(( sectors_in_kib=1024/$(cat /sys/block/${u2up_TARGET_DISK}/queue/hw_sector_size) ))

	if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	else
		u2up_TARGET_BOOT_PARTSZ=""
	fi
	root_part_label="$(get_root_label ${u2up_TARGET_DISK} ${u2up_TARGET_PART})"
	if [ -z "${root_part_label}" ]; then
		display_result "${action_name}" "${action_name} interrupted (unknown root part label)!"
		return 1
	fi
	if \
		[ -n "$u2up_TARGET_BOOT_PARTSZ" ] && \
		[ -n "$u2up_TARGET_ROOTA_PARTSZ" ] && \
		[ -n "$u2up_TARGET_ROOTB_PARTSZ" ] && \
		[ -n "$u2up_TARGET_LOG_PARTSZ" ]; \
	then
		# Dump current target disk setup:
		sfdisk -d /dev/${u2up_TARGET_DISK} > $U2UP_TARGET_DISK_SFDISK_DUMP
		rm -f $U2UP_TARGET_DISK_SFDISK_BASH

		# Warn, if partition table NOT GPT: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "label:" | grep "gpt" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! Partition table - wrong type\n"
			msg_warn="${msg_warn}\n=> Partition table is going to be recreated as GPT!\n"
			((msg_size+=4))
			((disk_change_needed+=1))
			cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo 'label: gpt' | sfdisk /dev/${u2up_TARGET_DISK}
EOF
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
sfdisk -d /dev/${u2up_TARGET_DISK} | grep -vE "^\/dev\/${u2up_TARGET_DISK}" > $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

########
# BOOT
########
		first_sector="$(sfdisk -d /dev/${u2up_TARGET_DISK} | grep "first-lba" | sed 's/^.*: //')"
		(( part_sectors=${u2up_TARGET_BOOT_PARTSZ}*${sectors_in_kib}*1024*1024 ))
		# Warn, if BOOT partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${u2up_TARGET_DISK}1" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}1) boot partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if BOOT partition NOT EFI: 
			check_part_type "EFI" "boot"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}1) boot partition - Not EFI type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if BOOT partition NOT SIZED: 
				check_part_size "boot"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}1) Boot partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${u2up_TARGET_DISK}1 : size= ${part_sectors}, type=${PART_TYPE_EFI}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

#######
# LOG
#######
		(( first_sector+=part_sectors ))
		(( part_sectors=${u2up_TARGET_LOG_PARTSZ}*${sectors_in_kib}*1024*1024 ))
		# Warn, if LOG partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${u2up_TARGET_DISK}2" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}2) log partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if LOG partition NOT LINUX: 
			check_part_type "Linux" "log"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}2) log partition - Not Linux type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if LOG partition NOT SIZED: 
				check_part_size "log"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}2) log partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${u2up_TARGET_DISK}2 : size= ${part_sectors}, type=${PART_TYPE_LINUX}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

#########
# ROOTA
#########
		(( first_sector+=part_sectors ))
		(( part_sectors=${u2up_TARGET_ROOTA_PARTSZ}*${sectors_in_kib}*1024*1024 ))
		# Warn, if ROOTA partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${u2up_TARGET_DISK}3" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}3) rootA partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if ROOTA partition NOT LINUX: 
			check_part_type "Linux" "rootA"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}3) rootA partition - Not Linux type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if ROOTA partition NOT SIZED: 
				check_part_size "rootA"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}3) rootA partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${u2up_TARGET_DISK}3 : size= ${part_sectors}, type=${PART_TYPE_LINUX}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

#########
# ROOTB
#########
		(( first_sector+=part_sectors ))
		(( part_sectors=${u2up_TARGET_ROOTB_PARTSZ}*${sectors_in_kib}*1024*1024 ))
		# Warn, if ROOTB partition MISSING: 
		if [ $(cat $U2UP_TARGET_DISK_SFDISK_DUMP | grep "/dev/${u2up_TARGET_DISK}4" | wc -l) -eq 0 ]; then
			msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}4) rootB partition - Missing\n"
			((msg_size+=2))
			((disk_change_needed+=1))
		else
		# Warn, if ROOTB partition NOT LINUX: 
			check_part_type "Linux" "rootB"
			if [ $? -ne 0 ]; then
				msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}4) rootB partition - Not Linux type\n"
				((msg_size+=2))
				((disk_change_needed+=1))
			else
		# Warn, if ROOTB partition NOT SIZED: 
				check_part_size "rootB"
				if [ $? -ne 0 ]; then
					msg_warn="${msg_warn}\n! (${u2up_TARGET_DISK}4) rootB partition - Resized\n"
					((msg_size+=2))
					((disk_change_needed+=1))
				fi
			fi
		fi
		cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
echo "/dev/${u2up_TARGET_DISK}4 : size= ${part_sectors}, type=${PART_TYPE_LINUX}" >> $U2UP_TARGET_DISK_SFDISK_DUMP
EOF

		if [ $disk_change_needed -ne 0 ]; then
			msg_fdisk="${msg_fdisk}\n-----------------------------------"
			msg_warn="${msg_warn}-----------------------------------\n"
			msg_warn="${msg_warn}\n=> Partition table is going to be changed and ALL TARGET DATA LOST!\n"
			((msg_size+=5))
			cat >> $U2UP_TARGET_DISK_SFDISK_BASH << EOF
sfdisk /dev/${u2up_TARGET_DISK} < $U2UP_TARGET_DISK_SFDISK_DUMP
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
				msg_warn="${msg_warn}\n=> [${u2up_TARGET_PART} - ${root_part_label}]\n"
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
		sfdisk -V /dev/${u2up_TARGET_DISK}
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
	local msg=""

	if [ $rv -eq 0 ]; then
		check_target_disk_configuration
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Target disk configuration check failed!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		check_current_target_disk_setup "Re-partition"
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Current target disk setup check failed!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		proceed_target_repartition
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Target disk repartition failed!"
		fi
	fi

	if [ $rv -ne 0 ]; then
		echo "${msg}" >&2
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
	local target_disk_current=$u2up_TARGET_DISK

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
		2>&1 >&3)
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
		current_set="$(save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} $selection)"
		if [ -n "$current_set" ]; then
			#Resize pressed: set new dialog values
			eval $current_set
		else
			#Ok
			save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "boot :${target_boot_partsz_current}"
			save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "log :${target_log_partsz_current}"
			save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "rootA :${target_rootA_partsz_current}"
			save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "rootB :${target_rootB_partsz_current}"
			execute_target_repartition
			return $?
		fi
	done
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
		2>&1 >&3)
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
		current_set="$(save_u2up_install_repo_selection ${U2UP_INSTALL_CONF_DIR} $selection)"
		if [ -n "$current_set" ]; then
			#Resize pressed: set new dialog values
			eval $current_set
		else
			#Ok
			save_u2up_install_repo_selection ${U2UP_INSTALL_CONF_DIR} "Base URL: ${install_repo_base_url_current}"
			(( rv+=$? ))
			return $rv
		fi
	done
}

get_prepare_images_bundle() {
	local rv=0
	local msg_warn=
	local msg_size=6
	local action_name="Get new images bundle"
	local INSTALL_REPO_BASE_URL=""

	source ${U2UP_INSTALL_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}
	INSTALL_REPO_BASE_URL=$u2up_INSTALL_REPO_BASE_URL
	mkdir -p ${U2UP_IMAGES_DIR}
	rv=$?
	if [ $rv -ne 0 ]; then
		return $rv
	fi
	cd ${U2UP_IMAGES_DIR} >&2
	if [ -f "${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}" ]; then
		mv -f ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM} ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}_existing
	fi
	echo "Get new images bundle checksum!" >&2
	wget ${INSTALL_REPO_BASE_URL}/${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
	rv=$?
	if [ $rv -ne 0 ]; then
		echo "Could not get new images bundle checksum!" >&2
		msg_warn="${msg_warn}\nCould not get new images bundle checksum (check access)!"
		((msg_size+=1))
		rm -f ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
		if [ -f "${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}_existing" ]; then
			mv -f ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}_existing ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
			msg_warn="${msg_warn}\nUsing existing images bundle checksum!"
			((msg_size+=1))
		else
			display_msg "${action_name}" "${msg_warn}" ${msg_size}
			cd - >&2
			return $rv
		fi
		rv=0
	else
		msg_warn="${msg_warn}\nGot new images bundle checksum!"
		((msg_size+=1))
	fi
	rm -f ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}_existing
	ln -sf ${U2UP_IMAGES_BUNDLE_ARCHIVE} $(cat ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM} | sed -e 's%^.* %%g')
	if [ -f "${U2UP_IMAGES_BUNDLE_ARCHIVE}" ]; then
		echo "Testing existing images bundle!" >&2
		sha256sum -c ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
		rv=$?
		if [ $rv -eq 0 ]; then
			msg_warn="${msg_warn}\nUsing existing images bundle (checksum OK)!"
			((msg_size+=1))
			display_msg "${action_name}" "${msg_warn}" ${msg_size}
			cd - >&2
			return $rv
		fi
		msg_warn="${msg_warn}\nExisting images bundle checksum mismatch!"
		((msg_size+=1))
		mv -f ${U2UP_IMAGES_BUNDLE_ARCHIVE} ${U2UP_IMAGES_BUNDLE_ARCHIVE}_existing
	fi
	echo "Get new images bundle!" >&2
	wget ${INSTALL_REPO_BASE_URL}/${U2UP_IMAGES_BUNDLE_ARCHIVE}
	rv=$?
	if [ $rv -ne 0 ]; then
		echo "Could not get new images bundle!" >&2
		msg_warn="${msg_warn}\nCould not get new images bundle (check access)!"
		((msg_size+=1))
		rm -f ${U2UP_IMAGES_BUNDLE_ARCHIVE}
		if [ -f "${U2UP_IMAGES_BUNDLE_ARCHIVE}_existing" ]; then
			mv -f ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}_existing ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
		fi
		display_msg "${action_name}" "${msg_warn}" ${msg_size}
		cd - >&2
		return $rv
	fi
	rm -f ${U2UP_IMAGES_BUNDLE_ARCHIVE}_existing
	echo "Using new images bundle!" >&2
	sha256sum -c ${U2UP_IMAGES_BUNDLE_ARCHIVE_SUM}
	if [ $? -ne 0 ]; then
		msg_warn="${msg_warn}\nNew images bundle checksum mismatch!"
	else
		msg_warn="${msg_warn}\nNew images bundle checksum OK!"
	fi
	((msg_size+=1))
	display_msg "${action_name}" "${msg_warn}" ${msg_size}
	cd - >&2
	return $rv
}

proceed_target_install() {
	local u2up_TARGET_DISK=""
	local u2up_TARGET_PART=""
	local root_part_suffix=""
	local msg=""
	local rv=0

	if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
		source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
	fi
	if [ $rv -eq 0 ] && [ -z "$u2up_TARGET_DISK" ]; then
		msg="Target disk not defined!"
		rv=1
	fi
	if [ $rv -eq 0 ] && [ -z "$u2up_TARGET_PART" ]; then
		msg="Target disk paritition not defined!"
		rv=1
	fi
	if [ $rv -eq 0 ]; then
		root_part_suffix="$(get_root_label_suffix ${u2up_TARGET_DISK} ${u2up_TARGET_PART})"
		if [ -z "$root_part_suffix" ]; then
			msg="Target root_part_suffix not defined!"
			rv=1
		fi
	fi
	if [ $rv -eq 0 ]; then
		check_create_filesystems $u2up_TARGET_DISK $u2up_TARGET_PART
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Failed checking / creating filesystems!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		mount_installation_filesystem $u2up_TARGET_DISK $u2up_TARGET_PART $root_part_suffix
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Failed mounting installation filesystem!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		extract_rootfs_from_images_bundle $u2up_TARGET_DISK $u2up_TARGET_PART $root_part_suffix
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Failed extracting root filesystem archive from images bundle!"
		fi
	fi
#spog - Currently not needed, because images-bundle is kept on the common "log" partition!
#	if [ $rv -eq 0 ]; then
#		echo "Populating the installed system with \"u2up-images-bundle\"..." >&2
#		populate_u2up_images_bundle "${U2UP_INSTALL_ROOT_MNT}" "${U2UP_IMAGES_DIR}" "${U2UP_IMAGES_BUNDLE_NAME}"
#		rv=$?
#		if [ $rv -ne 0 ]; then
#			msg="Failed populating the installed system with \"u2up-images-bundle\"!"
#		fi
#	fi
	if [ $rv -eq 0 ]; then
		echo "Populating the installed system with \"u2up-configurations\"..." >&2
		populate_u2up_configurations "${U2UP_INSTALL_ROOT_MNT}" "${U2UP_INSTALL_CONF_DIR}"
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Failed populating the installed system with \"u2up-configurations\"!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		update_filesystem_chrooted
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Failed updating installed system (chrooted)!"
		fi
	fi
	if [ $rv -ne 0 ]; then
		echo "${msg}" >&2
	fi

	return $rv
}

execute_target_install() {
	local rv=0
	local msg=""

	echo "Starting target installation..." >&2
	if [ $rv -eq 0 ]; then
		echo "Checking target configurations..." >&2
		check_target_configurations
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Target configurations check failed!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		echo "Checking current target disk setup..." >&2
		check_current_target_disk_setup "Installation"
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Current target disk setup check failed!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		echo "Checking installation images bundle initial content..." >&2
		check_images_bundle_initial_content
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Images bundle initial content check failed!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		echo "Proceeding target installation..." >&2
		proceed_target_install
		rv=$?
		if [ $rv -ne 0 ]; then
			msg="Proceeding target installation failed!"
		fi
	fi
	if [ $rv -eq 0 ]; then
		msg="Target installation successfully finished!"
	fi

	echo "${msg}" >&2
	echo "press enter to continue..." >&2
	read
	display_result "Installation" "${msg}"
	return $rv
}

main_loop () {
	local rv=1
	local current_tag='1'
	local root_part_label
	local net_external_mac=""
	local net_internal_mac=""
	local U2UP_CURRENT_ROOTFS_DATETIME=""
	local U2UP_BACKTITLE=""

	if [ ! -f "${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}" ]; then
		echo "Program terminated (missing: ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE})!" >&2
		exit 1
	fi
	source ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}
	if [ -z "${u2up_ROOTFS_DATETIME}" ]; then
		echo "Program terminated (missing current: u2up_ROOTFS_DATETIME)!" >&2
		exit 1
	fi
	U2UP_CURRENT_ROOTFS_DATETIME=${u2up_ROOTFS_DATETIME}
	U2UP_BACKTITLE="U2UP-HOMEGW installer - ${current_root_part_label} (${U2UP_CURRENT_ROOTFS_DATETIME}):"
	while true; do
		if [ -d "${U2UP_INSTALL_CONF_DIR}" ]; then
			for conf_file in $(ls ${U2UP_INSTALL_CONF_DIR}/*-conf); do
				source $conf_file
			done
		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_KEYMAP_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_KEYMAP_CONF_FILE}
#		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE}
#		fi
		root_part_label="$(get_root_label ${u2up_TARGET_DISK} ${u2up_TARGET_PART})"
		if [ -z "${root_part_label}" ]; then
			display_result "ERROR" "Program interrupted (unknown root part label)!"
			exit 1
		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_HOSTNAME_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_HOSTNAME_CONF_FILE}
#		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_ADMIN_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_TARGET_ADMIN_CONF_FILE}
#		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_NETWORK_EXTERNAL_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_NETWORK_EXTERNAL_CONF_FILE}
#		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_NETWORK_INTERNAL_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_NETWORK_INTERNAL_CONF_FILE}
#		fi
		net_external_mac=""
		if [ -n "${u2up_NET_EXTERNAL_IFNAME}" ]; then
			net_external_mac="$(ip link show dev $u2up_NET_EXTERNAL_IFNAME | grep "link\/ether" | sed 's/ *link\/ether *//' | sed 's/ .*//')"
		fi
		net_internal_mac=""
		if [ -n "${u2up_NET_INTERNAL_IFNAME}" ]; then
			net_internal_mac="$(ip link show dev $u2up_NET_INTERNAL_IFNAME | grep "link\/ether" | sed 's/ *link\/ether *//' | sed 's/ .*//')"
		fi
		net_home_mac=""
		if [ -n "${u2up_NET_HOME_IFNAME}" ]; then
			net_home_mac="$(ip link show dev $u2up_NET_HOME_IFNAME | grep "link\/ether" | sed 's/ *link\/ether *//' | sed 's/ .*//')"
		fi
#		if [ -f "${U2UP_INSTALL_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}" ]; then
#			source ${U2UP_INSTALL_CONF_DIR}/${U2UP_INSTALL_REPO_CONF_FILE}
#		fi

		exec 3>&1
		selection=$(dialog \
			--backtitle "${U2UP_BACKTITLE}" \
			--title "Menu - ${current_root_part_label} (${U2UP_CURRENT_ROOTFS_DATETIME})" \
			--clear \
			--cancel-label "Exit" \
			--default-item $current_tag \
			--menu "Please select:" $HEIGHT $WIDTH 16 \
			"1" "Keyboard mapping [${u2up_KEYMAP}]" \
			"2" "Target disk [${u2up_TARGET_DISK}]" \
			"3" "Disk partitions \
[boot:${u2up_TARGET_BOOT_PARTSZ}G] \
[log:${u2up_TARGET_LOG_PARTSZ}G] \
[rootA:${u2up_TARGET_ROOTA_PARTSZ}G] \
[rootB:${u2up_TARGET_ROOTB_PARTSZ}G]" \
			"4" "Hostname [${u2up_TARGET_HOSTNAME}]" \
			"5" "Administrator [${u2up_TARGET_ADMIN_NAME}]" \
			"6" "Network external interface [${u2up_NET_EXTERNAL_IFNAME} - ${net_external_mac}]" \
			"7" "Network internal interface [${u2up_NET_INTERNAL_IFNAME} - ${net_internal_mac}]" \
			"8" "Network home interface [${u2up_NET_HOME_IFNAME} - ${net_home_mac}]" \
			"9" "Static network external configuration [${u2up_NET_EXTERNAL_ADDR_MASK}]" \
			"10" "Static network internal configuration [${u2up_NET_INTERNAL_ADDR_MASK}]" \
			"11" "Local Domain [${u2up_LOCAL_DOMAIN}]" \
			"12" "Installation packages repo [${u2up_INSTALL_REPO_BASE_URL}]" \
			"13" "Installation partition [${u2up_TARGET_PART} - ${root_part_label}]" \
			"14" "Get new images bundle" \
			"15" "Install (${U2UP_IMAGE_ROOTFS_DATETIME})" \
			"16" "Default boot [${default_boot_label}]" \
			"17" "Reboot" \
		2>&1 >&3)
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
				$u2up_KEYMAP
			;;
		2)
#			display_target_disk_submenu \
#				$u2up_TARGET_DISK
			;;
		3)
#			local target_boot_partsz_old=$u2up_TARGET_BOOT_PARTSZ
#			local target_log_partsz_old=$u2up_TARGET_LOG_PARTSZ
#			local target_rootA_partsz_old=$u2up_TARGET_ROOTA_PARTSZ
#			local target_rootB_partsz_old=$u2up_TARGET_ROOTB_PARTSZ
#			display_target_partsizes_submenu \
#				$u2up_TARGET_BOOT_PARTSZ \
#				$u2up_TARGET_LOG_PARTSZ \
#				$u2up_TARGET_ROOTA_PARTSZ \
#				$u2up_TARGET_ROOTB_PARTSZ
#			rv=$?
#			if [ $rv -ne 0 ]; then
#				# Restore old partition sizes
#				save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "boot :${target_boot_partsz_old}"
#				save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "log :${target_log_partsz_old}"
#				save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "rootA :${target_rootA_partsz_old}"
#				save_u2up_target_partsize_selection ${U2UP_INSTALL_CONF_DIR} "rootB :${target_rootB_partsz_old}"
#			fi
			;;
		4)
			local target_hostname_old=$u2up_TARGET_HOSTNAME
			display_target_hostname_submenu \
				$U2UP_INSTALL_CONF_DIR \
				$u2up_TARGET_HOSTNAME
			;;
		5)
			local target_admin_name_old=$u2up_TARGET_ADMIN_NAME
			display_target_admin_submenu \
				$U2UP_INSTALL_CONF_DIR \
				$u2up_TARGET_ADMIN_NAME
			;;
		6)
			display_net_segment_ifname_submenu \
				$U2UP_INSTALL_CONF_DIR \
				External \
				$u2up_NET_EXTERNAL_IFNAME
			;;
		7)
			display_net_segment_ifname_submenu \
				$U2UP_INSTALL_CONF_DIR \
				Internal \
				$u2up_NET_INTERNAL_IFNAME
			;;
		8)
			display_net_segment_ifname_submenu \
				$U2UP_INSTALL_CONF_DIR \
				Home \
				$u2up_NET_HOME_IFNAME
			;;
		9)
			local net_external_mac_addr_old=$u2up_NET_EXTERNAL_MAC_ADDR
			local net_external_addr_mask_old=$u2up_NET_EXTERNAL_ADDR_MASK
			local net_external_gw_old=$u2up_NET_EXTERNAL_GW
			local net_external_dns1_old=$u2up_NET_EXTERNAL_DNS1
			local net_external_dns2_old=$u2up_NET_EXTERNAL_DNS2
			display_net_external_config_submenu \
				$U2UP_INSTALL_CONF_DIR \
				$u2up_NET_EXTERNAL_MAC_ADDR \
				$u2up_NET_EXTERNAL_ADDR_MASK \
				$u2up_NET_EXTERNAL_GW \
				$u2up_NET_EXTERNAL_DNS1 \
				$u2up_NET_EXTERNAL_DNS2
			rv=$?
			if [ $rv -ne 0 ]; then
				# Restore old network external configuration
				if [ -n "${net_external_mac_addr_mask}" ]; then
					save_u2up_net_external_config_selection ${U2UP_CONF_DIR} "MAC address: ${net_external_mac_addr_old}"
				fi
				if [ -n "${net_external_addr_mask_old}" ]; then
					save_u2up_net_external_config_selection ${U2UP_INSTALL_CONF_DIR} "IP address/mask: ${net_external_addr_mask_old}"
				fi
				if [ -n "${net_internal_gw_old}" ]; then
					save_u2up_net_external_config_selection ${U2UP_INSTALL_CONF_DIR} "IP gateway: ${net_external_gw_old}"
				fi
				if [ -n "${net_external_dns1_old}" ]; then
					save_u2up_net_external_config_selection ${U2UP_INSTALL_CONF_DIR} "DNS1: ${net_external_dns1_old}"
				fi
				if [ -n "${net_external_dns2_old}" ]; then
					save_u2up_net_external_config_selection ${U2UP_INSTALL_CONF_DIR} "DNS2: ${net_external_dns2_old}"
				fi
			else
				enable_u2up_net_external_config_selection
			fi
			;;
		10)
			local net_internal_mac_addr_old=$u2up_NET_INTERNAL_MAC_ADDR
			local net_internal_addr_mask_old=$u2up_NET_INTERNAL_ADDR_MASK
			local net_internal_gw_old=$u2up_NET_INTERNAL_GW
			display_net_internal_config_submenu \
				$U2UP_INSTALL_CONF_DIR \
				$u2up_NET_INTERNAL_MAC_ADDR \
				$u2up_NET_INTERNAL_ADDR_MASK \
				$u2up_NET_INTERNAL_GW
			rv=$?
			if [ $rv -ne 0 ]; then
				# Restore old network configuration
				if [ -n "${net_internal_mac_addr_mask}" ]; then
					save_u2up_net_internal_config_selection ${U2UP_CONF_DIR} "MAC address: ${net_internal_mac_addr_old}"
				fi
				if [ -n "${net_internal_addr_mask_old}" ]; then
					save_u2up_net_internal_config_selection ${U2UP_INSTALL_CONF_DIR} "IP address/mask: ${net_internal_addr_mask_old}"
				fi
				if [ -n "${net_internal_gw_old}" ]; then
					save_u2up_net_internal_config_selection ${U2UP_INSTALL_CONF_DIR} "IP gateway: ${net_internal_gw_old}"
				fi
			else
				enable_u2up_net_internal_config_selection
			fi
			;;
		11)
			local local_domain_old=$u2up_LOCAL_DOMAIN
			display_local_domain_submenu \
				$U2UP_INSTALL_CONF_DIR \
				$u2up_LOCAL_DOMAIN
			;;
		12)
			local install_repo_base_url_old=$u2up_INSTALL_REPO_BASE_URL
			display_install_repo_config_submenu \
				$u2up_INSTALL_REPO_BASE_URL
			rv=$?
			if [ $rv -ne 0 ]; then
				# Restore old installation packages repo configuration
				if [ -n "${install_repo_base_url_old}" ]; then
					save_u2up_install_repo_selection ${U2UP_INSTALL_CONF_DIR} "Base URL: ${install_repo_base_url_old}"
				fi
			else
				enable_u2up_install_repo_selection
			fi
			;;
		13)
			display_target_part_submenu \
				$u2up_TARGET_DISK \
				$u2up_TARGET_PART
			;;
		14)
			check_install_repo_config_set
			if [ $? -eq 0 ]; then
				get_prepare_images_bundle
				if [ $? -eq 0 ]; then
					check_images_bundle_initial_content
				fi
			fi

			;;
		15)
			execute_target_install
			default_boot_label="$(get_default_boot_label ${U2UP_CURRENT_TARGET_DISK})"
			;;
		16)
			display_target_boot_submenu
			default_boot_label="$(get_default_boot_label ${U2UP_CURRENT_TARGET_DISK})"
			;;
		17)
			display_yesno "Reboot" \
				"You are about to reboot the system!\n\nDo you want to continue?" 7
			if [ $? -eq 0 ]; then
				#Yes
				reboot
				exit 0
			fi
			;;
		esac
	done
}

check_images_bundle_initial_content

# Call main function:
main_loop

