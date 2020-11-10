HPE Cloud Volumes automation script
-----------------------------------

### Purpose of this project
This script offers an automated way to refresh an HPE cloud volumes presented to a cloud VM.
The script was tested in an AWS EC2 environment.

### Prerequisites

You should have an HPE Cloud Volumes account. cvctl should also be installed and configured in your target environment

### How to use the HPE Cloud Volumes API example script

1. Download the latest script from the Github page https://github.com/yannallandit/hpe-cloud-volumes-api-example
2. Copy the files init_cloud_volumes.sh & init_cloud_volumes.config in the same directory
3. Initialize your variable environments (replication store and replication volume) in init_cloud_volumes.config
4. Set securely your credentials for collecting the connection token in /usr/local/etc/cvuser and /usr/local/etc/cvpwd
5. (optional) set the crontab for automatic refresh at your own pace
6. Check init_cloud_volumes.sh has execution priviledges (otherwise chmod +x)
7. Run the script: ./init_cloud_volumes.sh


### New in this version 
- Delete multiple presented volumes 
- Use of a config file for storing the variables
- Update on Readme file

### Previous updates
- Initial release
