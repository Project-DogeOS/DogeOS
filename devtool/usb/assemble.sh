# usage: assemble.sh <dogeos-ver> <dist-iso-dir> <smartos-usb-img-path>

DOGEOS_VER=$1
DOGEOS_ISO_PATH=$2/${DOGEOS_VER}.iso
SMARTOS_USB_PATH=$3

USBIMG=${DOGEOS_VER}.img
USBSIZE=2000000000

# create img file
rm -rf $USBIMG
mkfile -n $USBSIZE $USBIMG
udev=$(lofiadm -a $USBIMG)

# create partition
# create partition
#echo "Will start fdisk, please cmds ('n', '1', 'C', '100', 'y', '6') in order: "
echo "Start fdisk new usb img"
echo "n
1
C
100
y
6
" | fdisk ${udev/lofi/rlofi}

# format the usb img
echo "yes" | mkfs -F pcfs -o fat=32 ${udev/lofi/rlofi}:c

# now mount & copy the init files
rm -rf u; mkdir u
mount -F pcfs $udev:c u

# now mount smartos usb
sdev=$(lofiadm -a $SMARTOS_USB_PATH)
rm -rf usbmnt; mkdir usbmnt
mount -F pcfs $sdev:c usbmnt

# now mount dogeos iso
idev=$(lofiadm -a $DOGEOS_ISO_PATH)
rm -rf isomnt; mkdir isomnt
mount -o ro -F hsfs $idev isomnt

# copy files
rsync -avz isomnt/ u/
rm -rf u/boot
rm -rf u/boot.catalog
cp -rv usbmnt/boot u/

# enable boot
umount u
lofiadm -d $udev
grub --batch <<____ENDOFGRUBCOMMANDS
device (hd0) $USBIMG
root (hd0,0)
setup (hd0)
quit
____ENDOFGRUBCOMMANDS

# clear devs, remove tmp files
umount isomnt
umount usbmnt
lofiadm -d $sdev
lofiadm -d $idev
