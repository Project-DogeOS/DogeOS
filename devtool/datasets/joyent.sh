# with no special instructions, all datasets are 64bit

getdatasets()
{
  NAME=$1
  UUID=$2
  wget https://images.joyent.com/images/${UUID} -O ${NAME}.dsmanifest
  wget -c https://images.joyent.com/images/${UUID}/file -O ${NAME}.gz
}

# http://wiki.joyent.com/wiki/display/jpc2/CentOS#CentOS-2.6.1
getdatasets CentOS-2.6.1 19daa264-c4c4-11e3-bec3-c30e2c0d4ec0

# http://wiki.joyent.com/wiki/display/jpc2/Ubuntu#Ubuntu-2.4.2
getdatasets Ubuntu-2.4.2 d2ba0f30-bbe8-11e2-a9a2-6bc116856d85

# http://wiki.joyent.com/wiki/display/jpc2/SmartMachine+Base#SmartMachineBase-14.1.0
getdatasets SmartMachineBase-14.1.0 8639203c-d515-11e3-9571-5bf3a74f354f

# http://wiki.joyent.com/wiki/display/jpc2/FreeBSD#FreeBSD-1.0.0
getdatasets FreeBSD-1.0.0 df8d2ee6-d87f-11e2-b257-2f02c6f6ce80

