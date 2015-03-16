#RH March 14 2015 - Stolen from Wandboard folder and modified
#RH - March 142015. This file is totally geared to getting u-boot and ubldr onto the media. There is nothing in hear abotu making or installing the kernel or rootfs
KERNCONF=DIGI-CCWMX53
TARGET_ARCH=armv6
IMAGE_SIZE=$((1024 * 1000 * 1000))
CCWMX53_UBOOT_SRC=${TOPDIR}/u-boot-2014.07 #RH I don't know where this is supposed to be?

#
# 3 partitions, a reserve one for uboot, a FAT one for the boot loader and a UFS one
#
# the kernel config (CCWMX53.common) specifies:
# U-Boot stuff lives on slice 1, FreeBSD on slice 2.
# options         ROOTDEVNAME=\"ufs:mmcsd0s2a\"
#
coreconnect_partition_image ( ) {
    disk_partition_mbr
    coreconnect_uboot_install
    disk_fat_create 50m 16 16384
    disk_ufs_create
}
strategy_add $PHASE_PARTITION_LWW coreconnect_partition_image

#
# coreconnect uses U-Boot.
#
coreconnect_check_uboot ( ) {
	# Crochet needs to build U-Boot.

    uboot_set_patch_version ${CCWMX53_UBOOT_SRC} ${CCWMX53_UBOOT_PATCH_VERSION}

    uboot_test \
        CCWMX53_UBOOT_SRC \
        "$CCWMX53_UBOOT_SRC/board/coreconnect/Makefile"
    strategy_add $PHASE_BUILD_OTHER uboot_patch ${CCWMX53_UBOOT_SRC} `uboot_patch_files`
    strategy_add $PHASE_BUILD_OTHER uboot_configure $CCWMX53_UBOOT_SRC ccwmx53js_config 
    strategy_add $PHASE_BUILD_OTHER uboot_build $CCWMX53_UBOOT_SRC
}
strategy_add $PHASE_CHECK coreconnect_check_uboot

#
# install uboot
#
coreconnect_uboot_install ( ) {
    echo Installing U-Boot to /dev/${DISK_MD}
    dd if=${CCWMX53_UBOOT_SRC}/u-boot.imx of=/dev/${DISK_MD} bs=512 seek=2
}

#
# ubldr
#
strategy_add $PHASE_BUILD_OTHER freebsd_ubldr_build UBLDR_LOADADDR=0x11000000
strategy_add $PHASE_BOOT_INSTALL freebsd_ubldr_copy_ubldr ubldr

#
# uEnv
#
coreconnect_install_uenvtxt(){
    echo "Installing uEnv.txt"
    cp ${BOARDDIR}/files/uEnv.txt .
}
#strategy_add $PHASE_BOOT_INSTALL coreconnect_install_uenvtxt

#
# DTS to FAT file system
#
coreconnect_install_dts_fat(){
    echo "Installing DTS to FAT"
    freebsd_install_fdt digi-ccwmx53.dts boot/kernel/digi-ccwmx53.dts 
    freebsd_install_fdt digi-ccwmx53.dts boot/kernel/digi-ccwmx53.dtb 
}
#strategy_add $PHASE_BOOT_INSTALL coreconnect_install_dts_fat

#RH - Don't know much about this yet. Flattened device tree and such
#
# DTS to UFS file system. This is in PHASE_FREEBSD_BOARD_POST_INSTALL b/c it needs to happen *after* the kernel install
#
coreconnect_install_dts_ufs(){
    echo "Installing DTS to UFS"
    freebsd_install_fdt digi-ccwmx53.dts boot/kernel/digi-ccwmx53.dts 
    freebsd_install_fdt digi-ccwmx53.dts boot/kernel/digi-ccwmx53.dtb 
}
strategy_add $PHASE_FREEBSD_BOARD_POST_INSTALL coreconnect_install_dts_ufs

#
# kernel
#
strategy_add $PHASE_FREEBSD_BOARD_INSTALL board_default_installkernel .
strategy_add $PHASE_FREEBSD_BOARD_INSTALL freebsd_ubldr_copy_ubldr_help boot

#
# Make a /boot/msdos directory so the running image
# can mount the FAT partition.  (See overlay/etc/fstab.)
#
strategy_add $PHASE_FREEBSD_BOARD_INSTALL mkdir boot/msdos

#
#  build the u-boot scr file
#
strategy_add $PHASE_BOOT_INSTALL uboot_mkimage ${CCWMX53_UBOOT_SRC} "files/boot.txt" "boot.scr"

