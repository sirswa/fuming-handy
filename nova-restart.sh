#!/bin/bash
# Author: Swe Aung sirswa[at]gmail[dot]com
# Date: 01/05/2013

function progress () {
        i=$1
	for (( c=1; c<=i; c++ ))
	do
       	   sleep 1
           echo -e "+ \c"
	done
}

echo -e "\nKill all dnsmasq             \c"
progress 2
/usr/bin/killall dnsmasq

echo -e "\nRestarting libvirt-bin       \c"
progress 5
/sbin/restart libvirt-bin 

echo -e "\nRestarting nova-api-metadata \c"
progress 5
/sbin/restart nova-api-metadata

echo -e "\nRestarting nova-network      \c"
progress 5
/sbin/restart nova-network

echo -e "\nRestarting nova-compute      \c"
progress 5
/sbin/restart nova-compute
