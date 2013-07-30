#!/bin/bash
# Author: Swe Aung sirswa[at]gmail[dot]com
# Date: 01/07/2013

[ $# -ne 2 ] && { echo -e "Usage: 
$0 <instanceID> <destination_host>" \\n; exit 1; }


tdate=`date +%Y%m%d`
ddir=$HOME/workspace/migration/$tdate
credential=$HOME/nectar-admin.sh

if [ ! -d "$ddir/$1" ]; then 
	wdir=$ddir/$1	
else
	wdir=$ddir/$1-`date +%Y%m%d%H%M`	
fi

mkdir -p $wdir

pre=$wdir/pre
post=$wdir/post

source $credential
nova show $1 > $pre.novashow

[ "$?" -ne 0 ] && { rm -rf $wdir; exit 1; }

shost=`cat $pre.novashow |grep "OS-EXT-SRV-ATTR:host"|awk '{print $4}'`

[ "$shost" = $2 ] && { echo "Error: Instrance is already running on $2."; rm -rf $wdir; exit 1; }

flavor=`cat $pre.novashow |grep "flavor"|awk '{print $4}'`

sip=`cat $pre.novashow |grep "monash-01 network"|awk '{print $5}'`

schain=`ssh $shost "sudo iptables -L"|grep $sip |awk '{print $1}'`

ssh $shost "sudo iptables -L $schain" > $pre.ipchain

[ ! -s $pre.ipchain ] && { echo "Instance IPCHAIN not found!"; rm -rf $wdir;exit 1; }

echo ""
echo -e "You are migrating:- Instance:\033[32m $1 \033[0m
		    Flavor  :\033[32m $flavor \033[0m
		    IP      :\033[32m $sip \033[0m
       	            From    :\033[32m $shost \033[0m
       		    To      :\033[32m $2 \033[0m"
echo ""

echo -e "\033[32mLive migration started at `date`.\033[0m"

nova live-migration --block-migrate $1 $2

stime=`date +%s`

while [ "$dhost" != "$2" ]; do 
	echo -e "+ \c"	
	dhost=`nova show $1 |grep "OS-EXT-SRV-ATTR:host"|awk '{print $4}'`
	sleep 10
done

etime=`date +%s`
ptime=`echo $etime - $stime | bc -l`
phr=`echo "$ptime" | awk '{print int($0/3600)"hr:"int($0%3600/60)"min:"$0%3600%60"sec"}'`

nova show $1 > $post.novashow

ssh $2 "sudo iptables -L $schain" > $post.ipchain

cat $pre.ipchain |grep -v "ACCEPT     udp  --  $shost.erc.monash.edu.au  anywhere             udp spt:bootps dpt:bootpc" > $pre.$shost.check
cat $post.ipchain |grep -v "ACCEPT     udp  --  $2.erc.monash.edu.au  anywhere             udp spt:bootps dpt:bootpc" > $post.$2.check

diff $pre.$shost.check $post.$2.check

if [ "$?" -eq "0" ]
then
	echo -e "\n\033[32mLive migration completed at `date` and it took $phr ($ptime seconds).\033[0m"
	echo "Instance ID: $1" > $post.summary
	echo "From: $shost" >> $post.summary
	echo "To: $2" >> $post.summary
	echo "IP: $sip" >> $post.summary
	echo "Flavor: $flavor" >> $post.summary
	echo "Time taken to migrate:  $phr ($ptime seconds)" >> $post.summary
else
	echo -e "\033[31mLive migration failed !!!\033[0m" 
	echo "Check the logs manually and migrate again"
fi
