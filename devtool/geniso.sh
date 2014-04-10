cd amd64
scp root@192.168.56.10:/opt/dogeos/boot_archive* .
cd -
#LC_ALL=C mkisofs -R -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -quiet -o dogeos-test.iso smartos-test/
