#!/bin/sh
#This script to be run at desktop which has direct connection to database server, or database server itself

#Set datebase credential. I prefer to keep it in separate file for more secure approach.
#I set mine on secure folder



sday=`date +%Y-%m-%d -d "-1 month -$(($(date +%d)-1)) days"`
eday=`date +%Y-%m%d -d "-$(date +%d) days -1 month"`
#sday="2013-07-01"
#eday="2013-07-31"
month=`date +%Y-%m -d "-1 month -$(($(date +%d)-1)) days"`

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
		where (created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at IS NULL)
		OR (created_at < '$sday 00:00:00' AND deleted_at > '$eday 23:59:59')";

echo ""
echo "New instances launched from $sday to $eday"
$CMD "use $DB; 
		select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors 
		from instances 
		where (created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')";

echo ""
echo "Running instances carried over from previous months"
$CMD "use $DB;
		select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors 
		from instances
		where (created_at < '$sday 00:00:00' AND deleted_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at IS NULL)
		OR (created_at < '$sday 00:00:00' AND deleted_at > '$eday 23:59:59') order by vcpus";

echo ""
echo "New instances break down by flavor"
$CMD "use $DB;
		select instance_types.name AS flavor,count(instance_types.name) AS count,instance_types.vcpus, sum(instances.vcpus)
		from instances 
		join instance_types on instances.instance_type_id = instance_types.id 
		where instances.uuid IS NOT NULL AND instances.host IS NOT NUll AND instances.created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59'
		group by instance_types.name order by vcpus";	

echo ""
echo "Carried over instances break down by flavor"
$CMD "use $DB;
		select instance_types.name AS flavor,count(instance_types.name) AS count,instance_types.vcpus, sum(instances.vcpus)
		from instances 
		join instance_types on instances.instance_type_id = instance_types.id 
		where (instances.created_at < '$sday 00:00:00' AND instances.deleted_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (instances.created_at < '$sday 00:00:00' AND instances.deleted_at IS NULL)
		OR (instances.created_at < '$sday 00:00:00' AND instances.deleted_at > '$eday 23:59:59')
		group by instance_types.name order by vcpus";

echo ""
echo "Age of instances launched in $month"
$CMD "use $DB;		
		select t6.5min as '<5mins',t1.l1hr as '<1hr',t2.1hr as '>1hr',t3.1day as '>1day',t4.7days as '>7days',t5.14days as '>14days'
		from
		(select count(uuid) as l1hr
		from instances
		where deleted_at < ( created_at + INTERVAL 1 HOUR) AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t1
		,
		(select count(uuid) as 1hr
		from instances
		where deleted_at >= ( created_at + INTERVAL 1 HOUR) AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t2
		,
		(select count(uuid) as 1day
		from instances
		where deleted_at >= ( created_at + INTERVAL 1 DAY) AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t3
		,
		(select count(uuid) as 7days
		from instances
		where deleted_at >= ( created_at + INTERVAL 7 DAY) AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t4
		,
		(select count(uuid) as 14days
		from instances
		where deleted_at >= ( created_at + INTERVAL 14 DAY) AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t5
		,
		(select count(uuid) as 5min
		from instances
		where deleted_at < ( created_at + INTERVAL 5 MINUTE) AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t6";


echo ""
echo "Utilisation % base on 44(out of 48) cpus cores x 48 compute nodes"	
$CMD "use $DB;
		#select t1.avail as 'Available', t2.util1, t3.util2, t4.util3, t5.util4, t6.util5, t7.util6
		select t1.avail as 'Available(sec)', (t2.util1 + t3.util2 + t4.util3 + t5.util4 + t6.util5 + t7.util6) as 'Utilisation(sec)', ((t2.util1 + t3.util2 + t4.util3 + t5.util4 + t6.util5 + t7.util6) / t1.avail) * 100 as '%'
		from
		## Get Available CPU in seconds
		(select SUM((UNIX_TIMESTAMP('$eday 23:59:59') - UNIX_TIMESTAMP('$sday 00:00:00')) * 2112) as avail) t1
		,
		## Get CPU Utilisation of instances created and deleted between $sday and $eday
		(select SUM((UNIX_TIMESTAMP(deleted_at) - UNIX_TIMESTAMP(created_at)) * vcpus) as util1
		from instances 
		where uuid IS NOT NULL AND host IS NOT NUll AND (created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') AND (deleted_at <= '$eday 23:59:59')) t2
		,
		## Get CPU Utilisation of instances deleted after $eday
		(select SUM((UNIX_TIMESTAMP('$eday 23:59:59') - UNIX_TIMESTAMP(created_at)) * vcpus) as util2
		from instances 
		where uuid IS NOT NULL AND host IS NOT NUll AND (created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') AND (deleted_at > '$eday 23:59:59')) t3
		,
		## Get CPU Utilisation of instances not yet deleted
		(select SUM((UNIX_TIMESTAMP('$eday 23:59:59') - UNIX_TIMESTAMP(created_at)) * vcpus) as util3
		from instances 
		where uuid IS NOT NULL AND host IS NOT NUll AND (created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') AND (deleted_at IS NULL)) t4
		,
		## Get CPU Utilisation of instances created before $sday and deleted between $sday and $eday
		(select SUM((UNIX_TIMESTAMP(deleted_at) - UNIX_TIMESTAMP('$sday 00:00:00')) * vcpus) as util4
		from instances 
		where created_at < '$sday 00:00:00' AND deleted_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59') t5
		,
		## Get CPU Utilisation of instances created before $sday and deleted after $eday
		(select SUM((UNIX_TIMESTAMP('$eday 23:59:59') - UNIX_TIMESTAMP('$sday 00:00:00')) * vcpus) as util5
		from instances 
		where created_at < '$sday 00:00:00' AND deleted_at > '$eday 23:59:59') t6
		,
		## Get CPU Utilisation of instances created before $sday and not yet deleted
		(select SUM((UNIX_TIMESTAMP('$eday 23:59:59') - UNIX_TIMESTAMP('$sday 00:00:00')) * vcpus) as util6
		from instances 
		where created_at < '$sday 00:00:00' AND deleted_at IS NULL) t7
		";	
		

echo ""
echo "Top 10 users of the month (desc by instances)"
$CMD "use $DB; 
		select user_id,COUNT(uuid) Instances,SUM(vcpus)
		from instances
		where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at IS NULL)
		OR (created_at < '$sday 00:00:00' AND deleted_at > '$eday 23:59:59')
		GROUP BY user_id ORDER BY Instances desc limit 10";


echo ""
echo "Top 10 projects of the month (desc by instances)"
$CMD "use $DB; 
		select project_id,COUNT(uuid) Instances,SUM(vcpus) CPUs 
		from instances 
		where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59')
		OR (created_at < '$sday 00:00:00' AND deleted_at IS NULL)
		OR (created_at < '$sday 00:00:00' AND deleted_at > '$eday 23:59:59')
		GROUP BY project_id ORDER BY Instances desc limit 10";
		
		
#echo ""
#echo "Detail report"
#echo "-------------"

#echo "Available CPU cores = 2112 (44cpu x 48 compute nodes)"
#nday=`date +%d --date="1 days ago"`
#nhr=`echo "$nday * 24 * 2112" | bc -l`
#echo "Available CPU hour = $nhr"


#$CMD "use $DB;
		

#####$CMD "use $DB;select COUNT(uuid) AS 'Total Instances',SUM(vcpus) AS 'Total CPUs',SUM(memory_mb) AS 'Total Memory MB', COUNT(DISTINCT user_id) AS Users, COUNT(DISTINCT project_id) AS Projects,COUNT(DISTINCT host) AS Hypervisors from instances where uuid IS NOT NULL AND created_at BETWEEN '$sday 00:00:00' AND '$eday 23:59:59'";

#echo ""
#echo "Hosts of the Month"

#$CMD "use $DB; select host,COUNT(uuid) Instances,SUM(vcpus) CPUs from instances where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '2013-06-01 00:00:00' AND '2013-06-30 23:59:59') OR (created_at < '2013-06-01 00:00:00' AND deleted <> 1 AND host IS NOT NULL) GROUP BY host ORDER BY Instances desc";


#echo""
#echo "Top 10 projects of the month (sort by instances)"
#$CMD "use $DB; select project_id,COUNT(uuid) Instances,SUM(vcpus) CPUs from instances where (uuid IS NOT NULL AND host IS NOT NUll AND created_at BETWEEN '2013-06-01 00:00:00' AND '2013-06-30 23:59:59') OR (created_at < '2013-06-01 00:00:00' AND deleted <> 1 AND host IS NOT NULL) GROUP BY project_id ORDER BY Instances desc limit 10";
