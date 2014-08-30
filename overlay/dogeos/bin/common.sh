# constant
OSPREFIX=[DogeOS]:

# val is the common return value var
var=

echo2console()
{
  echo $OSPREFIX $@ >/dev/sysmsg
}

#
# Get the max. IP addr for the given field, based in the netmask.
# That is, if netmask is 255, then its just the input field, otherwise its
# the host portion of the netmask (e.g. netmask 224 -> 31).
# Param 1 is the field and param 2 the mask for that field.
#
max_fld()
{
  if [ $2 -eq 255 ]; then
    fmax=$1
  else
    fmax=$((255 & ~$2))
  fi
}

#
# Converts an IP and netmask to a network
# For example: 10.99.99.7 + 255.255.255.0 -> 10.99.99.0
# Each field is in the net_a, net_b, net_c and net_d variables.
# Also, host_addr stores the address of the host w/o the network number (e.g.
# 7 in the 10.99.99.7 example above).  Also, max_host stores the max. host
# number (e.g. 10.99.99.254 in the example above).
#
ip_netmask_to_network()
{
  IP=$1
  NETMASK=$2

  OLDIFS=$IFS
  IFS=.
  set -- $IP
  net_a=$1
  net_b=$2
  net_c=$3
  net_d=$4
  addr_d=$net_d

  set -- $NETMASK

  # Calculate the maximum host address
  max_fld "$net_a" "$1"
  max_a=$fmax
  max_fld "$net_b" "$2"
  max_b=$fmax
  max_fld "$net_c" "$3"
  max_c=$fmax
  max_fld "$net_d" "$4"
  max_d=$(expr $fmax - 1)
  max_host="$max_a.$max_b.$max_c.$max_d"

  net_a=$(($net_a & $1))
  net_b=$(($net_b & $2))
  net_c=$(($net_c & $3))
  net_d=$(($net_d & $4))

  host_addr=$(($addr_d & ~$4))
  IFS=$OLDIFS
}

# Tests whether entire string is a number.
isdigit ()
{
  [ $# -eq 1 ] || return 1

  case $1 in
    *[!0-9]*|"") return 1;;
  *) return 0;;
  esac
}

# Tests network numner (num.num.num.num)
is_net()
{
  NET=$1

  OLDIFS=$IFS
  IFS=.
  set -- $NET
  a=$1
  b=$2
  c=$3
  d=$4
  IFS=$OLDIFS

  isdigit "$a" || return 1
  isdigit "$b" || return 1
  isdigit "$c" || return 1
  isdigit "$d" || return 1

  [ -z $a ] && return 1
  [ -z $b ] && return 1
  [ -z $c ] && return 1
  [ -z $d ] && return 1

  [ $a -lt 0 ] && return 1
  [ $a -gt 255 ] && return 1
  [ $b -lt 0 ] && return 1
  [ $b -gt 255 ] && return 1
  [ $c -lt 0 ] && return 1
  [ $c -gt 255 ] && return 1
  [ $d -lt 0 ] && return 1
  # Make sure the last field isn't the broadcast addr.
  [ $d -ge 255 ] && return 1
  return 0
}

promptval()
{
  val=""
  def="$2"
  while [ -z "$val" ]; do
    if [ -n "$def" ]; then
      printf "%s [%s]: " "$1" "$def"
    else
      printf "%s: " "$1"
    fi
    read val
    [ -z "$val" ] && val="$def"
    [ -n "$val" ] && break
    echo "A value must be provided."
  done
}

failAndExit()
{
  echo $@
  exit 1
}

# zexec_uuid is the global var to use with zlogin
zexec_uuid=

# set zexec_uuid
setZexecUUID()
{
  zexec_uuid=$1
}

zexec()
{
  if ![ -z "$zexec_uuid" ]; then
    zlogin $zexec_uuid $*
  fi
}

# dlg to show dialog, set backtitle first
dlg_backtitle=
dlg()
{
  dialog --backtitle "$backtitle" $*
}

# find GZ nic info, store them in 3 global array
#   gz_tags: nic tags, e.g., ['admin']
#   gz_macs: nic macs, e.g., ['d4:be:d9:a5:a5:85']
#   gz_links: nic links, e.g., ['e1000g0']
#   gz_nic_cnt: the count of nics
dogeosGetGZNicInfo()
{
  # Get local NIC info
  gz_nic_cnt=0
  while read -r mac tag link; do
    ((gz_nic_cnt++))
    gz_tags[$nic_cnt]=$tag
    gz_macs[$nic_cnt]=$mac
    gz_links[$nic_cnt]=$link
  done < <($NODE findnictag.js 2>/dev/null)
}

# find GZ admin nic's IP, return in $val
dogeosGetAdminNicIp()
{
  local dev=`$NODE findnictag.js | grep -w 'admin' | awk '{ print $3 }'`
  local ip=`ifconfig $dev | grep -w inet | awk '{ print $2 }'`
  val="$ip"
}

# find GZ admin nic's MAC, return in $val
dogeosGetAdminNicMac()
{
  local dev=`$NODE findnictag.js | grep -w 'admin' | awk '{ print $3 }'`
  local mac=`ifconfig $dev | grep -w 'ether' | awk '{ print $2 }'`
  val="$mac"
}

# decide live media type, return in $val
dogeosFindLiveMediaType()
{
  if [ -f /dogeos/liveusb ]; then
    val="usb"
  else
    val="dvd"
  fi
}

# decide live media dev path, if multiple, make user choose, return in $val
dogeosDecideMediaDev()
{
  local live_media_type=$1

  local dev_cnt=0
  local devs=
  declare -a dev_paths
  declare -a dev_names

  echo "Now finding your dev mount point (this will take up to 1min)..."
  while IFS=, read -r path name; do
    ((dev_cnt++))
    dev_paths[$dev_cnt]=$path
    dev_names[$dev_cnt]=$name
    if [ $dev_cnt -eq 1 ]; then
      devs=${devs}"$dev_cnt \"$name\" on"
    else
      devs=${devs}" $dev_cnt \"$name\" off"
    fi
  done < <($NODE findrmdev.js $live_media_type 2>/dev/null)

  local message=
  if [ $dev_cnt == 0 ]; then
    message="Can not found the dev object of DogeOS Live.

You may have chosen wrong. Please restart this program.
"
    dialog --backtitle "$backtitle" --msgbox "$message" 10 60
    exit 1
  fi

  local ret=
  local selected=
  val=
  if [ $dev_cnt == 1 ]; then
    val=${dev_paths[1]}
    return
  fi

  message="Your DogeOS Live type is: ${live_media_type}, but multiple media devices found. Please select your device of DogeOS Live:"
  while [ /usr/bin/true ]; do
    selected=$(dialog --backtitle "$backtitle" --radiolist "$message" 10 60 $dev_cnt $devs)
    ret=$?
    dogeosTestCancelled $ret; [ -n "$tocont" ] && continue
    break
  done

  val=${dev_paths[$selected]}
}

# fine zone ip by its UUID, return in $val
dogeosFindZoneIp()
{
  local UUID=$1
  cp findnicip.js /zones/$UUID/root/tmp/
  setZexecUUID $UUID
  ret=$(zexec "/opt/local/bin/node /tmp/findnicip.js")
  rm /zones/$UUID/root/tmp/findnicip.js
}

# for test dialog result == cancelled?
#   param 1: return code
#   param 2: confirm need?
# return in global var tocont
dogeosTestCancelled()
{
  local ret=$1
  local confirm=$2
  tocont=""

  if [ $ret -ne 0 ]; then
    if [ -z $confirm ]; then
      dialog --yesno "Really cancel?" 10 60
      if [ $? -ne 0 ]; then
        tocont="yes"
        return
      fi
    fi
    echo "As your wish, cancelled. Bye."
    exit $ret
  fi
}

# dlg for user to input a network IP, or dhcp
#   param #1: msg for what
# return in global var ret
dogeosSetIP()
{
  local ret=
  local what=$1
  local message="$what:
(IPv4 n.n.n.n or 'dhcp')
"
  val=""
  while [ -z "$val" ]; do
    val=$(dlg --stdout --no-cancel --inputbox "$message" 10 60 "dhcp")
    ret=$?
    dogeosTestCancelled $ret; [ -n "$tocont" ] && continue
    if [[ "$val" != "dhcp" ]]; then
      is_net "$val" || val=""
    fi
    [ -n "$val" ] && break
    dlg --msgbox "A valid IPv4 (n.n.n.n) or 'dhcp' must be provided." 10 60
  done
}

# dlg for user to input a network IP
#   param #1: msg for what
#   param #2: default value
# return in global var ret
dogeosSetNetIP()
{
  local ret=
  local what=$1
  local default=$2
  local message="$what:
(IPv4 n.n.n.n)
"
  val=""
  while [ -z "$val" ]; do
    val=$(dlg --stdout --no-cancel --inputbox "$message" 10 60 "$default")
    ret=$?
    dogeosTestCancelled $ret; [ -n "$tocont" ] && continue
    is_net "$val" || val=""
    [ -n "$val" ] && break
    dlg --msgbox "A valid network mask (n.n.n.n) must be provided." 10 60
  done
}

# dlg for user to input a root passwd
#   param #1: msg for what
# return in global var ret
dogeosSetRootPasswd()
{
  local ret=
  local what=$1
  val=""
  while [ -z "$val" ]; do
    val=$(dlg --stdout --insecure --no-cancel --passwordbox "Enter password for root of $what:" 10 60)
    ret=$?
    dogeosTestCancelled $ret
    if [ -z "$val" ]; then
      dlg --msgbox "A non-empty password must be provided." 10 60
      continue
    fi
    local cval=
    cval=$(dlg --stdout --insecure --no-cancel --passwordbox "Confirm password for root of $what:" 10 60)
    ret=$?
    dogeosTestCancelled $ret; [ -n "$tocont" ] && continue
    [ "$val" == "$cval" ] && break
    val=""
    dlg --msgbox "Two passwords do not match, please re-enter." 10 60
  done
}

# dlg for user to select a GZ nictag
#   param #1: msg for what
# return in global var ret
dogeosChooseNicTag()
{
  local what=$1
  local ret=
  local nics=
  local i=1

  if [ $gz_nic_cnt -eq 1]; then
    val=${gz_tags[0]}
    return
  fi

  while [ $i -le $gz_nic_cnt ]; do
    if [ $i -eq 1 ]; then
      nics=${nics}`printf "%d Link(%s),MAC(%s),TAG(%s) on" $i ${gz_links[$i]} ${gz_macs[$i]} ${gz_tags[$i]}`
    else
      nics=${nics}`printf " %d Link(%s),MAC(%s),TAG(%s) off" $i ${gz_links[$i]} ${gz_macs[$i]} ${gz_tags[$i]}`
    fi
    ((i++))
  done

  local message="Select the NIC of global zone to be used for $what:"
  local selected=

  while [ /usr/bin/true ]; do
    selected=$(dlg --stdout --no-cancel --radiolist "$message" 10 60 $gz_nic_cnt $nics)
    ret=$?
    dogeosTestCancelled $ret; [ -n "$tocont" ] && continue
    break
  done

  val=${gz_tags[$selected]}
}

dogeosCheckNetworkReachability()
{
  ping datasets.joyent.com 10 || failAndExit "Reach datasets.joyent.com failed. Check your network!"
  echo "datasets.joyent.com reached!"

  ping release.project-fifo.net 10 || failAndExit "Reach release.project-fifo.net failed. Check your network!"
  echo "release.project-fifo.net reached!"
}

dogeosImportImg()
{
  echo "Start import datasets ..."
  imgadm install -m $DOGEOS_EXTRA/dogeos/datasets/base64-13.2.1.dsmanifest  -f $DOGEOS_EXTRA/dogeos/datasets/base64-13.2.1.zfs.gz
  echo "Done"
}

dogeosFixJoyentManifest()
{
  echo "Start check joyent manifest..."
  local fixes="joyent joyent-minimal"
  for fix in $fixes
  do
    echo "Fix manifest of brand $fix..."
    cp ../share/joyent/manifest/sysconfig.xml /zones/manifests/$fix/milestone/
    echo "Done"
  done
  echo "All Done"
}
>>>>>>> e93f83c1d0624d1a69c8c89f04995e9ec9011ed2
