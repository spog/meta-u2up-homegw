#!/bin/bash
#
# Installation script for the new root-filesystem chrooted environment to
# finalize installation in a new environment.
#
#set -x

echo "Chrooted update script started!" >&2

echo "Setting initial (error) login banner of the installed system..." >&2
echo -e "U2UP (!!! THIS SYSTEM IS NOT CONFIGURED PROPERLY - check installation !!!)\n" > /etc/issue.d/z99-u2up.issue
if [ $? -ne 0 ]; then
	echo "Failed to set initial (error) login banner of the installed system!" >&2
	exit 1
fi
echo "Successfully set initial (error) login banner of the installed system!" >&2

U2UP_INSTALL_BASH_LIB="/lib/u2up/u2up-install-bash-lib"
if [ ! -f "${U2UP_INSTALL_BASH_LIB}" ]; then
	echo "Program terminated (missing: ${U2UP_INSTALL_BASH_LIB})!" >&2
	exit 1
fi
if [ -z "${U2UP_INSTALL_BASH_LIB_SOURCED}" ]; then
	source ${U2UP_INSTALL_BASH_LIB}
fi

current_target_disk=$(get_current_target_disk)
current_target_part=$(get_current_target_part)
current_root_part_label="$(get_root_label ${current_target_disk} ${current_target_part})"
if [ -z "${current_root_part_label}" ]; then
	echo "Program terminated (unrecognised current root disk and partition: disk=\"${current_target_disk}\", part=\"${current_target_part}\")!" >&2
	exit 1
fi
current_root_part_label_suffix="$(get_root_label_suffix_from_label ${current_root_part_label})"
if [ -z "${current_root_part_label_suffix}" ]; then
	echo "Program terminated (unrecognised current root partition label: disk=\"${current_target_disk}\", part=\"${current_target_part}\")!" >&2
	exit 1
fi

current_root_part_uuid="$(lsblk -ir -o NAME,PARTUUID /dev/${current_target_part} | grep -v "NAME" | sed 's/[a-z,0-9]* //')"
if [ -z "$current_root_part_uuid" ]; then
	echo "Local current_root_part_uuid empty!" >&2
	exit 1
fi

echo "Mounting /boot..." >&2
mount -t vfat -o umask=0077 /dev/${current_target_disk}1 /boot
if [ $? -ne 0 ]; then
	echo "Failed to mount /boot!" >&2
	exit 1
fi
echo "Successfully mounted /boot!" >&2

echo "Mounting /var/volatile/log..." >&2
mkdir -p /var/volatile/log
mount /dev/${current_target_disk}2 /var/volatile/log
if [ $? -ne 0 ]; then
	echo "Failed to mount /var/volatile/log!" >&2
	exit 1
fi
echo "Successfully mounted /var/volatile/log!" >&2

echo "Checking images bundle all content..." >&2
check_images_bundle_all_content
if [ $? -ne 0 ]; then
	echo "Failed checking images bundle all content!" >&2
	exit 1
fi
echo "Successfully checked images bundle all content!" >&2

echo "Extracting remaining content from images bundle..." >&2
extract_remaining_from_images_bundle ${current_root_part_label_suffix}
if [ $? -ne 0 ]; then
	echo "Failed extracting remaining content from images bundle!" >&2
	exit 1
fi
echo "Successfully extracted remaining content from images bundle!" >&2

echo "Creating new boot \"${current_root_part_label}\" menu entry..." >&2
if [ ! -f "${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}" ]; then
	echo "Program terminated (missing: ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE})!" >&2
	exit 1
fi
source ${U2UP_CONF_DIR}/${U2UP_IDS_CONF_FILE}
rv=0
echo "title ${current_root_part_label} (${u2up_ROOTFS_DATETIME})" > /boot/loader/entries/${current_root_part_label}.conf
((rv+=$?))
echo "linux /bzImage${current_root_part_label_suffix}" >> /boot/loader/entries/${current_root_part_label}.conf
((rv+=$?))
echo "options label=${current_root_part_label} root=PARTUUID=${current_root_part_uuid} rootwait rootfstype=ext4 console=tty0 ttyprintk.tioccons=1" >> /boot/loader/entries/${current_root_part_label}.conf
((rv+=$?))
echo "initrd /microcode${current_root_part_label_suffix}.cpio" >> /boot/loader/entries/${current_root_part_label}.conf
((rv+=$?))
if [ $rv -ne 0 ]; then
	echo "Failed to create new boot menu entry!" >&2
	exit 1
fi
echo "Successfully created new boot \"${current_root_part_label}\" menu entry!" >&2

echo "Configuring target keyboard mapping..." >&2
enable_u2up_keymap_selection
if [ $? -ne 0 ]; then
	echo "Failed to configure target keyboard mapping!" >&2
	exit 1
fi
echo "Successfully configured target keyboard mapping!" >&2

echo "Configuring target hostname..." >&2
enable_u2up_target_hostname_selection
if [ $? -ne 0 ]; then
	echo "Failed to configure target hostname!" >&2
	exit 1
fi
echo "Successfully configured target hostname!" >&2

echo "Configuring target admin..." >&2
enable_u2up_target_admin_selection
if [ $? -ne 0 ]; then
	echo "Failed to configure target admin!" >&2
	exit 1
fi
echo "Successfully configured target admin!" >&2

echo "Configuring \"fstab\" for common boot partition..." >&2
echo "/dev/${current_target_disk}1 /boot vfat umask=0077 0 1" >> /etc/fstab
if [ $? -ne 0 ]; then
	echo "Failed to configure \"fstab\" for common boot partition!" >&2
	exit 1
fi
echo "Successfully configured \"fstab\" for common boot partition!" >&2

echo "Configuring \"fstab\" for common logging partition..." >&2
echo "/dev/${current_target_disk}2 /var/log ext4 errors=remount-ro 0 1" >> /etc/fstab
if [ $? -ne 0 ]; then
	echo "Failed to configure \"fstab\" for common logging partition!" >&2
	exit 1
fi
echo "Successfully configured \"fstab\" for common logging partition!" >&2

#echo "Setting \"done\" configuring target disk and partitions..." >&2
#set_target_done_for ${U2UP_CONF_DIR}/${U2UP_TARGET_DISK_CONF_FILE} 1
#if [ $? -ne 0 ]; then
#	echo "Failed to set \"done\" configuring target disk and partitions!" >&2
#	exit 1
#fi
#echo "Successfully set \"done\" configuring target disk and partitions!" >&2

echo "Configuring \"internal network\" of the installed system..." >&2
#execute_net_reconfiguration
enable_u2up_net_config_selection
if [ $? -ne 0 ]; then
	echo "Failed to configure \"internal network\" of the installed system!" >&2
	exit 1
fi
echo "Successfully configured \"internal network\" of the installed system!" >&2

echo "Configuring SW packages repository for the installed system..." >&2
enable_u2up_install_repo_selection
if [ $? -ne 0 ]; then
	echo "Failed to configure SW packages repositoey for the installed system!" >&2
	exit 1
fi
echo "Successfully configured SW packages repositora for the installed system!" >&2

echo "Setting final login banner of the installed system..." >&2
echo -e "U2UP (use your admin-user to login:-)\n" > /etc/issue.d/z99-u2up.issue
if [ $? -ne 0 ]; then
	echo "Failed to set final login banner of the installed system!" >&2
	exit 1
fi
echo "Successfully set final login banner of the installed system!" >&2

echo "Chrooted update script successfully finished!" >&2

exit 0