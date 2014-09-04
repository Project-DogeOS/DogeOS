# copy pkg.js
cp $(readlink -e $(dirname $0))/pkg.js .

# download joyent pkg_summary
JOYENT_VER=2014Q2
mkdir -p joyent; cd joyent
  wget http://pkgsrc.joyent.com/packages/SmartOS/${JOYENT_VER}/x86_64/All/pkg_summary.bz2
  bunzip2 pkg_summary.bz2
cd -

# download fifo pkg_summary
mkdir -p fifo; cd fifo
  wget http://release.project-fifo.net/pkg/rel/pkg_summary.bz2
  bunzip2 pkg_summary.bz2
cd -

# download latest chunter
mkdir -p chunter; cd chunter
  curl -O http://release.project-fifo.net/chunter/rel/chunter-latest.gz
  curl -O http://release.project-fifo.net/chunter/rel/chunter.version
cd -
