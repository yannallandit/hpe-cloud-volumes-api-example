#!/bin/bash

##########################################
# Yann Allandit - HPE
##########################################

#################################
#### Instructions
# To run this file, first set the Cloud Volumes variables in init_cloud_volumes.config which must reside in the same directory as this script
# Then update your HPE Cloud Volumes credentiales stores in /usr/local/etc/cvuser and  /usr/local/etc/cvpwd
#################################


#### Variables
location="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
rep_store=`grep rep_store ${location}/init_cloud_volumes.config | cut -d "=" -f2`
rep_vol=`grep rep_vol ${location}/init_cloud_volumes.config | cut -d "=" -f2`
cvpwd=`sudo cat /usr/local/etc/cvpwd`
cvuser=`sudo cat /usr/local/etc/cvuser`
new_cloudvol_name=cloud_vol-test-$(date +%Y-%m-%d-%s)
token=`curl --location --request POST 'https://demo.cloudvolumes.hpe.com/auth/login' \
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "'${cvuser}'",
    "password": "'${cvpwd}'"
}' | jq -r .token`


#################################
#### Umount presented volume
#/usr/sbin/fuser -kmu /cv
cv_processes=`ps -ef | grep /cv | grep -v grep | awk '{print $2}'`
for i in ${cv_processes}
do
 kill -9 $i
done

/usr/bin/sudo umount /cv
/usr/bin/sudo vgchange -an

target_id=`/usr/bin/sudo /home/ec2-user/cvctl list cloudvolumes |grep mapper | awk '{print $6}'`
for i in $target_id
do	
   /usr/bin/sudo /home/ec2-user/cvctl disconnect cloudvolume --target-id $i
done

#echo "cvctl disconnect" $target_id
#read

#################################
#### Detach and delete previous cloud volumes
old_cloud_vol_array=`curl --location --request GET 'https://demo.cloudvolumes.hpe.com/api/v2/cloud_volumes?filters=marked_for_deletion=0' \
--header 'Content-Type: application/json' \
        --header "X-Auth-Token: ${token}" \
        | jq '. | .[] | .[] | .id' `


#echo "cloud vol array: " $old_cloud_vol_array
#read
sleep 120

#### for loop that detach and delete over each element in cloud volume list
for i in $old_cloud_vol_array
do
#    echo "cloud volume number id " ${i}
    initiator_ip=`curl --location --request GET "https://demo.cloudvolumes.hpe.com/api/v2/cloud_volumes/${i}" \
--header 'Content-Type: application/json' \
    --header "X-Auth-Token: ${token}" \
--data-raw '' \
| jq '.data.attributes.assigned_initiators' | jq .[] | jq -r '.ip'`

    initiator_ip=`echo ${initiator_ip%%*( )}`
#    echo "initiator_ip is: ***"${initiator_ip}"***"

    curl --location --request POST "https://demo.cloudvolumes.hpe.com/api/v2/cloud_volumes/${i}/detach" \
    --header 'Content-Type: application/json' \
    --header "X-Auth-Token: ${token}" \
    --data-raw '{
      "data":
      {
          "initiator_ip": "'${initiator_ip}'"
      }
    }'

    curl --location --request DELETE "https://demo.cloudvolumes.hpe.com/api/v2/cloud_volumes/${i}" \
    --header 'Content-Type: application/json' \
    --header "X-Auth-Token: ${token}"
done

#echo "delete old cv"
#read

##############################
#### Create Block/Cloud volumes
snap_ref=`curl --location --request GET "https://demo.cloudvolumes.hpe.com/api/v2/replication_stores/${rep_store}/replica_volumes/${rep_vol}/snapshots?sort=-creation_time" \
        --header 'Content-Type: application/json' \
        --header "X-Auth-Token: ${token}" \
        | jq '. | .[] | .[] | .id' | jq -s -r '. | .[0]'`

new_cloud_vol_id=`curl --location --request POST "https://demo.cloudvolumes.hpe.com/api/v2/replication_stores/${rep_store}/replica_volumes/${rep_vol}/clone" \
--header 'Content-Type: application/json' \
--header "X-Auth-Token: ${token}" \
--data-raw '{
    "data":
    {
        "name": "'${new_cloudvol_name}'",
        "snapshot_ref": "'${snap_ref}'",
        "region_id": 1,
        "iops": 300,
        "private_cloud": "vpc-0b0cda342897f06f1",
        "existing_cloud_subnet": "10.0.0.0/16"
    }
 }' | jq -r '.data.id' `

#echo " "
#echo "snapshot refeerence: " $snap_ref
#echo "new cloud volume id: " $new_cloud_vol_id
#echo " "
#read

############################
#### Present cloud volume
new_init_ip=`/usr/bin/hostname -I`
new_init_ip=`echo ${new_init_ip%%*( )}`
curl --location --request POST "https://demo.cloudvolumes.hpe.com/api/v2/cloud_volumes/${new_cloud_vol_id}/attach" \
--header 'Content-Type: application/json' \
--header "X-Auth-Token: ${token}" \
--data-raw '{
    "data":
    {
        "initiator_ip": "'${new_init_ip}'"
    }
}
'

#echo "new initiator_ip: ***" ${new_init_ip} "***"
#read

###############################
#### Connect volume to VM
target_name=`curl --location --request GET "https://demo.cloudvolumes.hpe.com/api/v2/cloud_volumes/${new_cloud_vol_id}" \
--header 'Content-Type: application/json' \
--header "X-Auth-Token: ${token}" \
| jq -r '.data.attributes.target_name' `

#echo " "
#echo "target name: " $target_name
#echo "cloud volume name: " ${new_cloudvol_name}
#echo " "
#read

/usr/bin/sudo /home/ec2-user/cvctl connect cloudvolume --name ${new_cloudvol_name} --discovery-ip 52.192.0.201 --target-name ${target_name} --chap-user 9b6a1767-3d4c-374e-a335-58cc96f31a5b --chap-secret jrDP6HEIsHvTXoP7

#echo "after cvctl connect cloudvolume"
#read

###############################
#### Scan lvm and mount volume
/usr/bin/sudo multipath -ll
/usr/bin/sudo lvmdiskscan
/usr/bin/sudo pvscan
/usr/bin/sudo vgscan
/usr/bin/sudo lvscan
/usr/bin/sudo vgchange -ay

/usr/bin/sudo mount /dev/cloudvol05/lcloudvol05 /cv


##########################
###### Display summary
echo "Summary"
echo "======="
echo "New cloud volume name: "$new_cloudvol_name
echo "snapshot reference: " $snap_ref
echo "new cloud volume id: "$new_cloud_vol_id
echo "target name: " $target_name
echo " "

