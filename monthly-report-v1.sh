#!/bin/sh
# Author: Swe Aung sirswa[at]gmail[dot]com
#This script to be run at desktop which has direct connection to database server, or database server itself

#Set datebase credential. I prefer to keep it in separate file for more secure approach.
#I set mine on secure folder

#smonth=`date -d "`date` -1 month" +%Y-%m-01`
#emonth=`date -d "$(date -d "`date` -1 month" +%Y-%m-01) +1 month -1 day" +%Y-%m-%d`

#sday=`date +%Y-%m-01`
sday="2013-07-01"
eday="2013-07-30"
#eday=`date +%Y-%m-%d --date="1 days ago"`
#month=`date +%Y-%m --date="1 days ago"`
month="2013-07"
#report=/srv/daily-statistics
#date -j -f date -j -f "%Y/%m/%d %T" "2009/10/15 04:58:06" +"%s"

FILE=nova.cnf

#Set your mysql client path
CMD="/usr/local/bin/mysql --defaults-file=$FILE -t -e"

#Set your database name
DB=nova_monash_01

echo ""
echo "Usage Summary for $month"
$CMD "use $DB;
		select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors 
		from instances 
		where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted = 0 AND host IS NOT NULL AND deleted_at IS NULL)";

echo ""
echo "New instances launched from $sday to $eday"
$CMD "use $DB; 
		select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors 
		from instances 
		where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')";

echo ""
echo "New instances break down by flavor"
$CMD "use $DB;
		select instance_types.name AS flavor,count(instance_types.name) AS count,instance_types.vcpus, sum(instances.vcpus)
		from instances 
		join instance_types on instances.instance_type_id = instance_types.id 
		where instances.uuid IS NOT NULL AND instances.host IS NOT NUll AND instances.created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59'
		group by instance_types.name order by vcpus";	

echo ""
echo "Running instances carried over from previous month"
$CMD "use $DB;
		select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors 
		from instances
		where created_at < '$sday 00:00:00' AND deleted = 0 AND host IS NOT NULL AND deleted_at IS NULL";

#echo ""
#echo "Carried over instances break down by flavor"
#$CMD "use $DB;
#		select instance_types.name AS flavor,count(instance_types.name) AS count,instance_types.vcpus, sum(instances.vcpus)
#		from instances 
#		join instance_types on instances.instance_type_id = instance_types.id 
#		where instances.created_at < '$sday 00:00:00' AND instances.deleted = 0 AND instances.host IS NOT NULL AND instances.deleted_at IS NULL
#		group by instance_types.name order by vcpus";	


echo ""
echo "Top 10 users of the month (sort by instances)"
$CMD "use $DB; 
		select user_id,COUNT(uuid) Instances,SUM(vcpus) 
		from instances where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '2013-06-01 00:00:00' AND '2013-06-30 23:59:59') 
		OR (created_at < '2013-06-01 00:00:00' AND deleted = 0  AND host IS NOT NULL AND deleted_at IS NULL) GROUP BY user_id ORDER BY Instances desc limit 10";

echo""
echo "Top 10 projects of the month (sort by instances)"
$CMD "use $DB; 
		select project_id,COUNT(uuid) Instances,SUM(vcpus) CPUs 
		from instances where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '2013-06-01 00:00:00' AND '2013-06-30 23:59:59') 
		OR (created_at < '2013-06-01 00:00:00' AND deleted = 0 AND host IS NOT NULL AND deleted_at IS NULL) GROUP BY project_id ORDER BY Instances desc limit 10";



echo ""
echo "Detail report"
echo "-------------"

echo "Available CPU cores = 2112 (44cpu x 48 compute nodes)"
nday=`date +%d --date="1 days ago"`
nhr=`echo "$nday * 24 * 2112" | bc -l`
echo "Available CPU hour = $nhr"


#$CMD "use $DB;
		

#####$CMD "use $DB;select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors from instances where uuid IS NOT NULL AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59'";

#echo ""
#echo "Hosts of the Month"

#$CMD "use $DB; select host,COUNT(uuid) Instances,SUM(vcpus) CPUs from instances where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '2013-06-01 00:00:00' AND '2013-06-30 23:59:59') OR (created_at < '2013-06-01 00:00:00' AND deleted <> 1 AND host IS NOT NULL) GROUP BY host ORDER BY Instances desc";


#echo""
#echo "Top 10 projects of the month (sort by instances)"
#$CMD "use $DB; select project_id,COUNT(uuid) Instances,SUM(vcpus) CPUs from instances where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '2013-06-01 00:00:00' AND '2013-06-30 23:59:59') OR (created_at < '2013-06-01 00:00:00' AND deleted <> 1 AND host IS NOT NULL) GROUP BY project_id ORDER BY Instances desc limit 10";
