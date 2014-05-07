echo -n "Input your slide dir name:"
read dirname
mkdir $dirname
cd $dirname
cp ../reveal.js/index.html .
ln -s ../reveal.js/css css
ln -s ../reveal.js/js js
ln -s ../reveal.js/plugin plugin
ln -s ../reveal.js/lib lib
cd ..
echo "Done."
