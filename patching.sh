#!/bin/bash
#Author: Kuddus
# This script is used to generate patching reports.
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,KeyName,PrivateIpAddress]' --output table | awk -F "|" '/i-/ {print $2 $3 $4}' > instance_info
#ip=aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,KeyName,PrivateIpAddress]' --output table | awk -F "|" '/i-/ {print $4}'
#instance_ids=aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,KeyName,PrivateIpAddress]' --output table | awk -F "|" '/i-/ {print $2}' > instance_ids
function pre_patch_output
{
        for server in $(cat server)
        do
                
		keys=$(cat instance_info | grep -i $server  | awk '{print $2}')  
		location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
		nc -w 10 -vz $server 22 &> /dev/null
		if [ $? -eq 0 ]
		then
		echo "Server $server is up" >> $server.log
		echo "Starting Pre Patch Report" >> $server.log
                echo "+---------------+-------------------+--------+---------------------+" >> $server.log
                echo "|=============================$server==============================|" >> $server.log
                echo "+---------------+-------------------+--------+---------------------+" >> $server.log
                echo "=======================+===Kernel Version===========================" >> $server.log
                version=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} uname -r) >> $server.log
                echo "$version" >> $server.log
                echo "==========================Disk Space Utilization====+===============" >> $server.log
                disk_space=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} df -kh)
                echo "$disk_space" >> $server.log
                echo "===========================Netstat Utilization=======================" >> $server.log
                net=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} netstat -auln)
                echo "$net" >> $server.log
                echo "===========================Grub Configuration File===================" >> $server.log
                ginfo=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} cat /etc/grub.conf)
                echo "$ginfo" >> $server.log
                echo "======================Previos Package Information====================" >> $server.log
                rpminfo=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${keys}.pem rpm -qa --last)
                echo "$rpminfo" >> $server.log
                echo "============================Ending Pre Patch report==================" >> $server.log
		else
			echo "$server is down. Please start the machine and try again......." >> $server.log
		fi

        done

}
function pre_patch_report
{
        for server in $(cat server)
        do
	keys=$(cat instance_info | grep -i $server  | awk '{print $2}')
        location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
        nc -w 10 -vz $server 22 &> /dev/null
        if [ $? -eq 0 ]
	then
        echo "Package Name,Package Version" >> $server.csv
        sec=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${keys}.pem yum check-update --security | grep -A2000 "security" | awk 'NR>=3 {print $1","$2}')
        echo "$sec" >> $server.csv
	else
		echo "Server is down................."
	fi
        done

}
function patchinstance
{
#           python amibackup.py $1 'us-east-1'
#           [ $? -ne 0 ] && echo "AMI Backup failed for instance $1" && return
           for IP in $(cat server)
           do
                ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem sudo yum update --security -y &> ${server}_patching.log
		if [ $? -eq 0 ]
                then
                        echo "$sec" >> ${server}_patching.log
                        echo "Patching Successfully Completed" >> ${server}_patching.log
			today_date=$(date '+%b %m')
			no_lines=$(ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem sudo grep -i "$(date '+%b')" /var/log/yum.log | grep -i "$(date '+%m')"| wc -l )
			if [ $no_lines -ne 0 ] 
			then  
			ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem sudo reboot >> ${server}_patching.log  						   
			sleep 100 

			fi
			kernel_ver=$(ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem uname -r) 
			[ $? -eq 0 ] && echo "Server is up after server patching with $kernel_ver " >> ${server}_patching.log

                else
                        echo "Patching failed" >> ${server}_patching.log
		fi
           done


}

pre_patch_output
pre_patch_report
for server in $(cat server)
do
	keys=$(cat instance_info | grep -i $server  | awk '{print $2}')
        location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
        nc -w 10 -vz $server 22 &> /dev/null
        if [ $? -eq 0 ]
	then
	
		instance_id=$(cat instance_info | grep -i $server | awk '{print $1} ')
        	$(patchinstance $instance_id | tee -a $instance_id.log) &
	else
		echo "$server is down.................."
	fi
done
data=`jobs | wc -l`

while [ $data -ne 0 ]
do
    data=`jobs | wc -l`
    jobs
    sleep 10
done

