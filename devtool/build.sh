# Auto build a DogeOS from scratch

# Work Dir:
#  /opt/dogeos-build/
#  (make sure it is empty, and build.sh is in it)

# debug switch
#set -x trace

# First please modify following conf vars

# ver 0.6.0
#SMARTOS_VER=20140501T225642Z
#FIFO_VER=0.6.0
#JOYENT_VER=2014Q2 # ref http://pkgsrc.joyent.com/packages/SmartOS/
#DATASETS_NAME=base64-14.2.0
#DATASETS_UUID=d34c301e-10c3-11e4-9b79-5f67ca448df0

# ver 0.4.5
SMARTOS_VER=20140501T225642Z
FIFO_VER=0.4.5
JOYENT_VER=2014Q1 # ref http://pkgsrc.joyent.com/packages/SmartOS/
DATASETS_NAME=base64-13.2.1
DATASETS_UUID=17c98640-1fdb-11e3-bf51-3708ce78e75a

DOGEOS_VER=DogeOS-${SMARTOS_VER}-${FIFO_VER}

###############################################################################

# Internal vars

WGET="wget --no-check-certificate"

CWD=`pwd`
BTD=$(readlink -e $(dirname $0)) # build tool dir
DOGED=$(readlink -e $BTD/../) # dogeos repo dir

# Step 1: download all required resources

# SmartOS distros
rm -rf smartos; mkdir smartos
cd smartos
  $WGET https://us-east.manta.joyent.com//Joyent_Dev/public/SmartOS/${SMARTOS_VER}/smartos-${SMARTOS_VER}.iso
  $WGET https://us-east.manta.joyent.com//Joyent_Dev/public/SmartOS/${SMARTOS_VER}/smartos-${SMARTOS_VER}-USB.img.bz2
  bunzip2 smartos-${SMARTOS_VER}-USB.img.bz2
cd -

# DogeOS distro, in dogeos dir
rm -rf dogeos
  ln -s $DOGED dogeos # make symlink to dogeos repo

# chunter, in chunter dir
rm -rf chunter; mkdir chunter
cd chunter
  $WGET http://release.project-fifo.net/chunter/rel/chunter-latest.gz
  $WGET http://release.project-fifo.net/chunter/rel/chunter.version
cd -

# prepare extra dir
mkdir -p extra/dogeos

# Fifo distro, in fifo dir
rm -rf pkgs/fifo-${FIFO_VER}; mkdir -p pkgs/fifo-${FIFO_VER}
cd pkgs/fifo-${FIFO_VER}
  $WGET http://release.project-fifo.net/pkg/rel/pkg_summary.bz2
  bunzip2 pkg_summary.bz2
  gzip -c pkg_summary >pkg_summary.gz
  bzip2 pkg_summary
  $WGET -i ../../dogeos/devtool/extra/fifo-filelist-${FIFO_VER}.txt
cd -
ln -s ../../pkgs/fifo-${FIFO_VER} extra/dogeos/fifo

# fifo zone img datasets
rm -rf datasets/${DATASETS_NAME}; mkdir -p datasets/${DATASETS_NAME}
cd datasets/${DATASETS_NAME}
  $WGET https://datasets.joyent.com/datasets/${DATASETS_UUID} -O ${DATASETS_NAME}.dsmanifest
  $WGET https://datasets.joyent.com/datasets/${DATASETS_UUID}/${DATASETS_NAME}.zfs.gz
cd -
ln -s ../../datasets/${DATASETS_NAME} extra/dogeos/datasets

# joyent pkgs, in joyent dir
rm -rf pkgs/joyent-{JOYENT_VER}; mkdir -p pkgs/joyent-${JOYENT_VER}
cd pkgs/joyent-${JOYENT_VER}
  $WGET -i ../../dogeos/devtool/extra/joyent-filelist-${JOYENT_VER}.txt
cd -
ln -s ../../pkgs/joyent-${JOYENT_VER} extra/dogeos/joyent

# prepare the dist dir & change to it
rm -rf dist; mkdir dist
cd dist

# Step 2: assemble first boot_archive in dir dist
rm -rf boot_archive; mkdir boot_archive
cd boot_archive
  cp $CWD/dogeos/devtool/boot_archive/* .
  ./first_assemble.sh $CWD/smartos/smartos-${SMARTOS_VER}.iso $CWD/dogeos $CWD/chunter
cd -

# Step 3: assemble ISO
rm -rf iso; mkdir iso
cd iso
  cp $CWD/dogeos/devtool/iso/assemble.sh .
  ./assemble.sh "dogeos-${SMARTOS_VER}-${FIFO_VER}" $CWD/boot_archive $CWD/smartos/smartos-${SMARTOS_VER}.iso $CWD/extra
cd -

# Step 4: assemble USB
rm -rf usb; mkdir usb
cd usb
  cp $CWD/dogeos/devtool/usb/assemble.sh .
  ./assemble.sh "dogeos-${SMARTOS_VER}-${FIFO_VER}" $CWD/iso $CWD/smartos/smartos-${SMARTOS_VER}-USB.img
cd -

# Step 5: cleanup work
cd $CWD
