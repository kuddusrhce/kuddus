function post_patch_report()
{
        for server_list in $(cat server.txt)
        do

                keys=$(cat instance_info | grep -i $server_list  | awk '{print $2}')
                location=$( find /home/ec2-user -name ${keys}.pem | tail -1)
                nc -w 10 -vz $server_list 22 &> /dev/null
                if [ $? -eq 0 ]
                then
                echo "Server $server_list is up" >> ${server_list}__post_patch.log
                echo "Starting Pre Patch Report" >> ${server_list}_post_patch.log
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
                echo "======================Previos Package Information====================" >> ${server_list}_post_patch.log
                rpminfo_post=$(ssh -o StrictHostKeyChecking=No ec2-user@$server_list -i ${keys}.pem rpm -qa --last)
                echo "$rpminfo_post" >> ${server_list}_post_patch.log
				echo "============================Ending Pre Patch report==================" >> ${server_list}_post_patch.log
                echo "Package Name,Instance Date" >> ${server_list}_post_patch.csv
                rpminfo1=$(ssh -o StrictHostKeyChecking=No ec2-user@$server -i ${keys}.pem sudo rpm -qa --last |  awk '{out=$1","$2; for(i=3;i<=NF;i++){out=out" "$i}; print out}')
                echo "$rpminfo1" >> ${server}_pre_patch.csv


                else
                        echo "$server is down. Please start the machine and try again......."
                        echo "$server is down. Please start the machine and try again......." >> ${server_list}_post_patch.log
                fi

        done
		
}

post_patch_report
