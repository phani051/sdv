#Ask for server name
echo "Enter server name(Please give FQDN): "
read server_name
echo $server_name

#Get GPN
server_gpn=$(echo $server_name | sed 's/-nebr././'| sed 's/-ebr././')

#Old method to check from nslookup
#server_fqdn=$(nslookup $server_name | sed -n 4p | awk '{print $2 }')
#server_short=$(nslookup $server_name | sed -n 4p | awk '{print $2 }' | cut -d '.' -f 1)
#server_short=$(echo $server_name |cut -d '-' -f 1 |cut -d '.' -f 1)

#Get Master server details from bp.conf
master_server=$(ssh -o StrictHostKeyChecking=no $server_gpn ""cat /usr/openv/netbackup/bp.conf | sed -n 1p | awk '{print $3 }' | tail -1"")
#master_short=$(echo "$master_server" | cut -d '.' -f 1 | cut -d '-' -f 1 )

#Get Master GPN and Client name as per bp.conf
master_gpn=$(echo $master_server | sed 's/-nebr././'| sed 's/-ebr././' )
client_name=$(ssh -o StrictHostKeyChecking=no $server_gpn ""cat /usr/openv/netbackup/bp.conf | grep '^CLIENT_NAME' | awk '{print $3}'"")
 
#Backup Status
 
backup_status=$(ssh -o StrictHostKeyChecking=no $master_gpn ""/usr/openv/netbackup/bin/bpclimagelist -U -client $client_name -s $( date -d "3 day ago" +%m/%d/%Y)"")
 
 
#Restore
echo " Running test restore"

# Prep for restore
ssh -o StrictHostKeyChecking=no $master_gpn " touch /tmp/filelist.txt /tmp/rename.txt && echo 'change /opt/openv/netbackup/logs/ to /tmp/restored' > /tmp/rename.txt && echo '/opt/openv/netbackup/logs/README.debug' > /tmp/filelist.txt"

# Initiate restore and get restore ID
restore_id=$(ssh -o StrictHostKeyChecking=no $master_gpn "sudo /usr/openv/netbackup/bin/bprestore -C $client_name -D $client_name -R /tmp/rename.txt -f /tmp/filelist.txt -print_jobid | sed s/.*=//")

# Give time for restore completion
sleep 30s
echo -e "\n"

# Get restore job status
restore=$(ssh -o StrictHostKeyChecking=no $master_gpn ""/usr/openv/netbackup/bin/admincmd/bpdbjobs -report | grep $restore_id | awk '{print "Job ID:" $1 "  Client: "$5 "   Status:" $4}'"")
restore_exit_code=$(ssh -o StrictHostKeyChecking=no $master_gpn ""/usr/openv/netbackup/bin/admincmd/bpdbjobs -report | grep $restore_id | awk '{print "" $4}'"")
 
#Check restore status code
if [$restore_exit_code == 0 ]; then
restore_status="Success"
else
restore_status="Failed"
fi
 
 
#Policy and schedule details
 
ssh -o StrictHostKeyChecking=no $master_gpn ""/usr/openv/netbackup/bin/admincmd/bppllist -byclient $client_name -U"" >/tmp/policy_$server_name
policy=$(cat /tmp/policy_$server_name | grep 'Policy Name\|Policy Type'| awk '{print $3}' | grep -i Standard -B 1 | tail -2 |head -1)
 
ssh -o StrictHostKeyChecking=no $master_gpn ""sudo /usr/openv/netbackup/bin/admincmd/bpplsched $policy -U "" >/tmp/schedule_$server_name
schedule=$(cat /tmp/schedule_$server_name | grep -m 10 'FULL\|day' | grep -v 'Frequency\|exclude')
 
# Complete Output

echo -e "\n"
echo "Client name is $client_name"
echo "Master server is $master_server"
echo -e "\n"
echo "======== Last 3days backup images ==========="
echo "$backup_status"
echo -e "\n"
 
echo "Restore Job ID: $restore_id"
echo "Restore Status: $restore_status"
echo "Restore Test (Pathname/Filename)  : /opt/openv/netbackup/logs/README.debug"
 
echo -e "\n"
echo "Full Backup Schedule : yes"
echo "Policy is $policy"
echo -e "\n"
echo "$schedule"