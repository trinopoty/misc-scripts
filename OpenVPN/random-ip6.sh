#!/bin/bash

gen_ipv6_addr () {
	local prefix=$1
	local addr=$prefix$(dd if=/dev/urandom bs=1 count=8 2> /dev/null | xxd -p|sed -re 's/(.{4})/:\1/g')
	echo $addr
}

_config_file="$1"

_prefix_ipv6=${ifconfig_ipv6_local%%::*}
prefix_ipv6_parts=$(echo "$_prefix_ipv6" | awk -F":" '{print NF-1}')
if [ $prefix_ipv6_parts -lt "3" ]; then
    _prefix_ipv6="$_prefix_ipv6:"
fi

_addr_ipv6=$(gen_ipv6_addr $_prefix_ipv6)

echo "ifconfig-ipv6-push $_addr_ipv6" > $_config_file

