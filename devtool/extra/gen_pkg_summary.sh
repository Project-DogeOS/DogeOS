# $1 is the filelist file
# $2 is the category name
#   e.g., ../extra/gen_pkg_summary.sh ../filelist/fifo-filelist-0.6.0.txt fifo
for f in `cat $1`; do
  node pkg.js $2/pkg_summary pkg_summary $(basename $f);
done
