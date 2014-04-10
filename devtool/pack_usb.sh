set -e

curdir=`pwd`
bi_usbpath="$curdir/workplace.usb"
bi_tmpdir=$curdir/workplace.usb.mnt

function bi_generate_usb_file
{
  echo "Generating usb image file... \c "
  rm -f $bi_usbpath
  mkfile -n 2000000000 $bi_usbpath
  rm -rf $bi_tmpdir
  mkdir $bi_tmpdir
  bi_lofidev=$(lofiadm -a $bi_usbpath)
  fdisk -F $curdir/usb_fdisk_table ${bi_lofidev/lofi/rlofi}
  mkfs -F pcfs -o fat=32 ${bi_lofidev/lofi/rlofi}:c
  echo "done"
  echo "Mounting usb image file... \c "
  mount -F pcfs ${bi_lofidev}:c $bi_tmpdir
  echo "done"
}

function bi_copy_contents
{
  echo "Copying ... \c "
  rsync -rv --exclude "/platform/i86pc/amd64/boot_archive" $curdir/smartosusb/ $bi_tmpdir/
  echo "next ... \c "
  cp $curdir/boot_archive* $bi_tmpdir/platform/i86pc/amd64/
  echo "done"
}

function bi_generate_usb
{
  echo "Installing grub... \c "
  grub --batch <<____ENDOFGRUBCOMMANDS
device (hd0) $bi_usbpath
root (hd0,0)
setup (hd0)
quit
____ENDOFGRUBCOMMANDS
  echo "done"
  umount ${bi_lofidev}:c
  lofiadm -d $bi_lofidev
  echo "Compressing usb image... \c "
  pbzip2 $bi_usbpath
  echo "done"
  mv ${bi_usbpath}.bz2 dogeos-test-USB.bz2
  echo "usb image is available at ${curdir}/dogeos-test-USB.bz2"
}

bi_generate_usb_file

echo "mounting original USB..."
smartosusbdev=$(lofiadm -a $curdir/smartos-20131003T221245Z-USB.img)
mount -o ro -F pcfs $smartosusbdev:c smartosusb
echo "done"
bi_copy_contents
umount smartosusb
lofiadm -d $curdir/smartos-20131003T221245Z-USB.img

bi_generate_usb

