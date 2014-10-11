MEDIAPATH=$(readlink -e $(dirname $0)) # iso media mounted path

rm -rf /opt/dogeos; mkdir -p /opt/dogeos
cd /opt/dogeos

# step 0: copy the boot_archive
mkdir ./tmp
cp -v $MEDIAPATH/platform/i86pc/amd64/boot_archive ./tmp

# step 1: copy all dogeos files
badev=$(lofiadm -a ./tmp/boot_archive)
rm -rf ./tmp/bamnt; mkdir -p ./tmp/bamnt
mount $badev ./tmp/bamnt
rsync -avz ./tmp/bamnt/dogeos/* ./
umount ./tmp/bamnt
lofiadm -d $badev

# step 2: copy all resources into right places
rsync -avz $MEDIAPATH/dogeos ./mnt/dogeos-extra/

# step 3: mark this as smartdoge
touch ./smartdoge

# step 4: link /opt/dogeos -> /dogeos and make it persistent
ln -nsf /opt/dogeos /dogeos
DOGEOS_CUSTOM_SMF="<?xml version='1.0'?>
<!DOCTYPE service_bundle SYSTEM '/usr/share/lib/xml/dtd/service_bundle.dtd.1'>
<service_bundle type='manifest' name='export'>
  <service name='site/smartdoge' type='service' version='0'>
    <create_default_instance enabled='true'/>
    <single_instance/>
    <dependency name='network' grouping='require_all' restart_on='error' type='service'>
      <service_fmri value='svc:/milestone/network:default'/>
    </dependency>
    <dependency name='filesystem' grouping='require_all' restart_on='error' type='service'>
      <service_fmri value='svc:/system/filesystem/local'/>
    </dependency>
    <method_context/>
    <exec_method name='start' type='method' exec='ln -nsf /opt/dogeos /dogeos' timeout_seconds='60'/>
    <exec_method name='stop' type='method' exec=':kill' timeout_seconds='60'/>
    <property_group name='startd' type='framework'>
      <propval name='duration' type='astring' value='transient'/>
      <propval name='ignore_error' type='astring' value='core,signal'/>
    </property_group>
    <property_group name='application' type='application'/>
    <stability value='Evolving'/>
    <template>
      <common_name>
        <loctext xml:lang='C'>Link root .bashrc to /opt/custom/.bashrc</loctext>
      </common_name>
    </template>
  </service>
</service_bundle>"
mkdir -p /opt/custom/smf
echo $DOGEOS_CUSTOM_SMF >/opt/custom/smf/smartdoge.xml

# final: clear all tmp files
rm -rf ./tmp

cd -
