VER_SMARTOS=20140404T001635Z
VER_FIFO=0.4.4

cd amd64
scp root@192.168.56.10:/opt/dogeos/boot_archive* .
cd -

LC_ALL=C mkisofs -R -b boot/grub/stage2_eltorito --follow-links -no-emul-boot -boot-load-size 4 -boot-info-table -quiet -o dogeos-${VER_SMARTOS}-${VER_FIFO}.iso cdrom/
