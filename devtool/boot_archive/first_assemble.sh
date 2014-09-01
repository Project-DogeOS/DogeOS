# usage: ./first_assemble.sh <smartos-iso> <dogeos-dir> <chunter-dir>
SMARTOS_ISO_SRC=$1
DOGEOS_OVERLAY=$2/overlay
CHUNTER_DIR=$3

# init the workplace first
./workplace_init.sh
wdev=$(lofiadm -a boot_archive)
mount $wdev workplace

# copy & mount smartos iso
sdev=$(lofiadm -a ${SMARTOS_ISO_SRC})
rm -rf isomnt; mkdir -p isomnt
mount $sdev isomnt

# copy all from smartos iso to workplace
rsync -avz isomnt/ workplace/

# copy dogeos overlay
cp -rLv ${DOGEOS_OVERLAY}/* workplace/

# copy chutner release
cp -rLv ${CHUNTER_DIR}/* workplace/dogeos/share/fifo/

# close lofi devs, rm tmp files
umount isomnt
lofiadm -d $sdev

# now first pack
./pack.sh
