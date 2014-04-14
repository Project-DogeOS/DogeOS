umount workplace
lofiadm -d boot_archive
digest -a sha1 boot_archive >boot_archive.hash
mount `lofiadm -a boot_archive` workplace
