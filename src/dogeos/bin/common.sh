OSPREFIX=[DogeOS]:

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

