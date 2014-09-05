set -e
mkfile 300000k boot_archive
badev=$(lofiadm -a boot_archive)
echo "yes" | newfs -o space -m 0 -i 12248 -b 4096 ${badev}
lofiadm -d boot_archive
mkdir workplace
