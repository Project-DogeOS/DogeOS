echo "Now start to build DogeOS..."
rm -rf build; mkdir build
cd build
../devtool/build.sh
cd -
echo "All done."
