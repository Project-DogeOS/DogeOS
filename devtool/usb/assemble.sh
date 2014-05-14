# usage: assemble.sh <dogeos-ver> <dist-iso-dir> <smartos-usb-img-path>

DOGEOS_VER=$1
DOGEOS_ISO_PATH=$2
SMARTOS_USB_PATH=$3

USBIMG=dogeos-${DOGEOS_VER}.img
USBSIZE=2000000000

# create img file
rm -rf $USBIMG
mkfile -n $USBSIZE $USBIMG
udev=$(lofiadm -a $USBIMG)

# create partition
echo "Will start fdisk, please cmds ('n', '1', 'C', '100', 'y', '6') in order: "
fdisk ${udev/lofi/rlofi}

# format the usb img
mkfs -F pcfs -o fat=32 ${udev/lofi/rlofi}:c

# now mount & copy the init files
rm -rf u
mount -F pcfs $udev:c u

# now mount smartos usb
sdev=$(lofiadm -a $SMARTOS_USB_PATH)
rm -rf usbmnt; mkdir usbmnt
mount -F pcfs $sdev:c usbmnt

# now mount dogeos iso
idev=$(lofiadm -a $DOGEOS_ISO_PATH)
rm -rf isomnt; mkdir isomnt
mount $idev isomnt

# copy files
rsync -avz isomnt/ u/
rm u/boot.catalog
cp -r usbmnt/boot u/

# enable boot
umount u
grub --batch <<____ENDOFGRUBCOMMANDS
device (hd0) $USBIMG
root (hd0,0)
setup (hd0)
quit
____ENDOFGRUBCOMMANDS

# clear devs, remove tmp files
lofiadm -d $udev
lofiadm -d $sdev
lofiadm -d $idev
