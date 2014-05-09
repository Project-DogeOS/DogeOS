USBSIZE=2000000000
VER_SMARTOS=20140404T001635Z
VER_FIFO=0.4.4
USBBOOT_SRC=

set -e

USBIMG=dogeos-${VER_SMARTOS}-${VER_FIFO}.img

# create img file
rm -rf $USBIMG
mkfile -n $USBSIZE $USBIMG
udev=$(lofiadm -a $USBIMG)

# create partition
echo "Will start fdisk, please input cmd: "
fdisk ${udev/lofi/rlofi}

# format the usb img
mkfs -F pcfs -o fat=32 ${udev/lofi/rlofi}

# now mount & copy the init files
rm -rf u
mount -F pcfs $udev u
scp -r $USBBOOT_SRC u/

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
