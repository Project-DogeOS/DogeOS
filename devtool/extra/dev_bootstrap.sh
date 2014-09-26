#!/bin/sh

confirm () {
  # call with a prompt string or use a default
  read -r -p "${1:-Are you sure?}[y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      true
      ;;
    *)
      false
      ;;
  esac
}

# copy pkg.js
cp $(readlink -e $(dirname $0))/pkg.js .

# download joyent pkg_summary
confirm "Download joyent pkg_summary ?"
if [[ $? -eq 0 ]]; then
  JOYENT_VER=2014Q2
  mkdir -p joyent; cd joyent
    wget http://pkgsrc.joyent.com/packages/SmartOS/${JOYENT_VER}/x86_64/All/pkg_summary.bz2
    bunzip2 pkg_summary.bz2
  cd -
else
  echo "skipped"
fi

# download fifo pkg_summary
confirm "Download fifo pkg_summary ?"
if [[ $? -eq 0 ]]; then
  mkdir -p fifo; cd fifo
    wget http://release.project-fifo.net/pkg/rel/pkg_summary.bz2
    bunzip2 pkg_summary.bz2
  cd -
else
  echo "skipped"
fi

# download latest chunter
confirm "Download latest chunter ?"
if [[ $? -eq 0 ]]; then
  mkdir -p chunter; cd chunter
    curl -O http://release.project-fifo.net/chunter/rel/chunter.version
    curl -O http://release.project-fifo.net/chunter/rel/chunter-latest.gz
  cd -
else
  echo "skipped"
fi
