#!/bin/bash
#Author: Kuddus
# This script is used to generate patching reports.
function pre_patch_output
{
	for server in $(cat server)
        do
        	echo "Starting Pre Patch Report" > $server.log
        	echo "+---------------+-------------------+--------+---------------------+" >> $server.log
        	echo "|=============================$server==============================|" >> $server.log
        	echo "+---------------+-------------------+--------+---------------------+" >> $server.log
        	echo "=======================+===Kernel Version===========================" >> $server.log
		version=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i key.pem uname -r) >> $server.log
        	echo "$version" >> $server.log
		echo "==========================Disk Space Utilization====+===============" >> $server.log
        	disk_space=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i key.pem df -kh)
        	echo "$disk_space" >> $server.log
		echo "===========================Netstat Utilization=======================" >> $server.log
        	net=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i key.pem netstat -auln)
        	echo "$net" >> $server.log
		echo "===========================Grub Configuration File===================" >> $server.log
        	ginfo=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i key.pem cat /etc/grub.conf)
        	echo "$ginfo" >> $server.log
		echo "======================Previos Package Information====================" >> $server.log
		rpminfo=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i key.pem rpm -qa --last)
		echo "$rpminfo" >> $server.log
		echo "============================Ending Pre Patch report==================" >> $server.log
        
	done

}
function pre_patch_report
{
	for server in $(cat server)
	do
	echo "Package Name,Package Version" >> $server.csv
	sec=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i key.pem yum check-update --security | grep -A2000 "security" | awk 'NR>=3 {print $1","$2}')
 	echo "$sec" >> $server.csv
	done
	
}
function patching
{
	   python amibackup.py $1 'ap-southeast-1'
           [ $? -ne 0 ] && echo "AMI Backup failed for instance $1" && return
	   for IP in $(cat server)
           do
        	sec=$(ssh -o StrictHostKeyChecking=No ec2-user@$IP -i key.pem yum update --security -y) >> patching_log
		if [ $? -eq 0 ]
		then
		       	echo "$sec" >> $patching_log
			echo "Patching Successfully Completed" >> $patching_log
		else
			echo "Patching failed" >> $patching_log
           done


}

#pre_patch_output
#pre_patch_report
for i in $(cat instance_id)
do
	$(patchinstance $i | tee -a $i.log) &
done

data=`jobs | wc -l`

while [ $data -ne 0 ]
do
    data=`jobs | wc -l`
    jobs
    sleep 10
done
