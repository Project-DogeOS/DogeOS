DOGEOS_SRC=
SMARTOS_ISO_SRC=
TMPDIR=tmp

# init the workplace first
./workplace_init.sh
wdev=$(lofiadm -a boot_archive)
mount $wdev workplace

# prepare tmp dir
rm -rf ${TMPDIR}
mkdir ${TMPDIR}

# copy & mount smartos iso
scp ${SMARTOS_ISO_SRC} ${TMPDIR}/smartos-latest.iso
sdev=$(lofiadm -a ${TMPDIR}/smartos-latest.iso)
mkdir -p ${TMPDIR}/sliso
mount $sdev ${TMPDIR}/sliso

# copy all from smartos iso to workplace
rsync -avz ${TMPDIR}/sliso/ workplace/

# copy dogeos overlay
scp -r ${DOGEOS_SRC}/* workplace/

# close lofi devs, rm tmp files
umount ${TMPDIR}/sliso
lofiadm -d $sdev

# now first pack
./pack.sh
