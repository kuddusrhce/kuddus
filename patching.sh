#!/bin/bash
#Author: Kuddus
# This script is used to generate patching reports.
#aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,KeyName,PrivateIpAddress]' --output table | awk -F "|" '/i-/ {print $2 $3 $4}' > instance_info
#ip=aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,KeyName,PrivateIpAddress]' --output table | awk -F "|" '/i-/ {print $4}'
#instance_ids=aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,KeyName,PrivateIpAddress]' --output table | awk -F "|" '/i-/ {print $2}' > instance_ids
function pre_patch_output
{
        for server in $(cat server.txt)
        do

                keys=$(cat instance_info | grep -i $server  | awk '{print $2}')
                location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
                nc -w 10 -vz $server 22 &> /dev/null
                if [ $? -eq 0 ]
                then
                echo "Server $server is up" >> ${server}_pre_patch.log
                echo "Starting Pre Patch Report" >> ${server}_pre_patch.log
                echo "+---------------+-------------------+--------+---------------------+" >> ${server}_pre_patch.log
                echo "|=============================$server==============================|" >> ${server}_pre_patch.log
                echo "+---------------+-------------------+--------+---------------------+" >> ${server}_pre_patch.log
                echo "=======================+===Kernel Version===========================" >> ${server}_pre_patch.log
                version=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} sudo uname -r) >> ${server}_pre_patch.log
                echo "$version" >> ${server}_pre_patch.log
                echo "==========================Disk Space Utilization====+===============" >> ${server}_pre_patch.log
                disk_space=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} sudo df -kh)
                echo "$disk_space" >> ${server}_pre_patch.log
                echo "===========================Netstat Utilization=======================" >> ${server}_pre_patch.log
                net=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} sudo netstat -auln)
                echo "$net" >> ${server}_pre_patch.log
                echo "===========================Grub Configuration File===================" >> ${server}_pre_patch.log
                ginfo=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${location} sudo cat /etc/grub.conf)
                echo "$ginfo" >> ${server}_pre_patch.log
                echo "======================Previos Package Information====================" >> ${server}_pre_patch.log
                rpminfo=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${keys}.pem sudo rpm -qa --last)
                echo "$rpminfo" >> ${server}_pre_patch.log
                echo "============================Ending Pre Patch report==================" >> ${server}_pre_patch.log
                echo "Package Name,Package Version" >> ${server}_pre_patch.csv
                sec=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${keys}.pem sudo yum check-update --security | grep -A2000 "security" | awk 'NR>=3 {print $1","$2}')
                echo "$sec" >> ${server}_pre_patch.csv
		echo "Package Name,Installation date" >> ${server}_pre_patch.csv
		rpminfo1=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${keys}.pem sudo rpm -qa --last |  awk '{out=$1","$2; for(i=3;i<=NF;i++){out=out" "$i}; print out}')
		echo "$rpminfo1" >> ${server}_pre_patch.csv
				
                else
	                echo "$server is down. Please start the machine and try again......." 
	  		echo "$server is down. Please start the machine and try again......." >> ${server}_pre_patch.log
                fi

        done
}
function patchinstance
{
           #python amibackup.py $1 'us-east-1'
           #[ $? -ne 0 ] && echo "AMI Backup failed for instance $1" && return
	     IP=$(cat instance_info | grep -i "$1" | awk -F" " '{print $3}')	
             sec_update=$(ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem sudo yum update --security -y) >> ${IP}_patching.log
		if [ $? -eq 0 ]
                then
			echo "yum update --security -y " >> ${IP}_patching.log 
                        echo "$sec_update" >> ${IP}_patching.log
			no_lines=$(ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem sudo grep -i "$(date '+%b\ %d ')" /var/log/yum.log |  wc -l )
			if [ $no_lines -ne 0 ] 
			then  
			ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem sudo reboot >> ${IP}_patching.log  		
				
			echo "$IP is rebooting now after patching" | tee -a ${IP}_patching.log
			sleep 10
			while ! nc -w 10 -vz ${IP} 22 &> /dev/null
			do
    				printf "%c" "."
			done
			printf "\n%s\n"  "$IP Server is back online" >>  ${IP}_patching.log
			
			kernel_ver=$(ssh -o StrictHostKeyChecking=No ec2-user@$IP -i ${keys}.pem uname -r) 
			[ $? -eq 0 ] && echo "Server is up after server patching with $kernel_ver " >> ${IP}_patching.log
			echo "Patching activity completed on $IP"
			echo "Patching activity completed on $IP" >> ${IP}_patching.log
			else
			echo "No Patches found for $IP server" >> ${IP}_patching.log
			fi
                else
                        echo "Patching Activity failed on $IP" | tee -a  ${IP}_patching.log
		fi
}
function post_patch_report
{
        for server_list in $(cat server.txt)
        do

                keys=$(cat instance_info | grep -i $server_list  | awk '{print $2}')
                location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
                nc -w 10 -vz $server_list 22 &> /dev/null
                if [ $? -eq 0 ]
                then
                echo "Starting Post Patch Report" >> ${server_list}_post_patch.log
                echo "+---------------+-------------------+--------+---------------------+" >> ${server_list}_post_patch.log
                echo "|=============================$server_list==============================|" >> ${server_list}_post_patch.log
                echo "+---------------+-------------------+--------+---------------------+" >> ${server_list}_post_patch.log
                echo "=======================+===Kernel Version===========================" >> ${server_list}_post_patch.log
                version_post=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${location} uname -r)
                echo "$version_post" >> ${server_list}_post_patch.log
                echo "==========================Disk Space Utilization====+===============" >> ${server_list}_post_patch.log
                disk_space_post=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${location} df -kh)
                echo "$disk_space_post" >> ${server_list}_post_patch.log
                echo "===========================Netstat Utilization=======================" >> ${server_list}_post_patch.log
                net_post=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${location} netstat -auln)
                echo "$net_post" >> ${server_list}_post_patch.log
                echo "===========================Grub Configuration File===================" >> ${server_list}_post_patch.log
                ginfo_post=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${location} cat /etc/grub.conf)
                echo "$ginfo_post" >> ${server_list}_post_patch.log
                echo "======================Package Information====================" >> ${server_list}_post_patch.log
                rpminfo_post=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${keys}.pem rpm -qa --last)
                echo "$rpminfo_post" >> ${server_list}_post_patch.log
		echo "============================Ending Post Patch report==================" >> ${server_list}_post_patch.log
                echo "Package Name,Instance Date" >> ${server_list}_post_patch.csv
                rpminfo1=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${keys}.pem sudo rpm -qa --last |  awk '{out=$1","$2; for(i=3;i<=NF;i++){out=out" "$i}; print out}')
                echo "$rpminfo1" >> ${server_list}_post_patch.csv


                else
                        echo "$server is down. Please start the machine and try again......."
                        echo "$server is down. Please start the machine and try again......." >> ${server_list}_post_patch.log
                fi

        done
		
}

pre_patch_output
for server_line in $(cat server.txt)
do
	keys=$(cat instance_info | grep -i $server_line  | awk '{print $2}')
        location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
        nc -w 10 -vz $server_line 22 &> /dev/null
        if [ $? -eq 0 ]
	then
	
	instance_id=$(cat instance_info | grep -i $server_line | awk '{print $1} ')
       	$(patchinstance $instance_id | tee -a $instance_id.log) &
	else
		echo "$server_line is down.................." | tee -a $instance_id.log
	fi
done
data=`jobs | wc -l`

while [ $data -ne 0 ]
do
    data=`jobs | wc -l`
    jobs
    sleep 10
done

post_patch_report
