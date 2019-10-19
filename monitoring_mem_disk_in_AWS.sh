#!/usr/bin/env bash

# Install and configure:
# Monitoring Memory and Disk Metrics for Amazon EC2 Linux Instances
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html

set -euo pipefail
#set -x # Uncomment to enable verbosity

# Prerequisites

f_amz_linux (){
    DEPS_AMZ_LINUX=(
        perl-Switch
        perl-DateTime
        perl-Sys-Syslog
        perl-LWP-Protocol-https
        perl-Digest-SHA.x86_64
	    )
    sudo yum -y install ${DEPS_AMZ_LINUX[@]}

 # Download, install, and configure the monitoring scripts
VERSION="1.2.2"
curl "https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-${VERSION}.zip" -O
unzip "CloudWatchMonitoringScripts-${VERSION}.zip" && \
rm -rf "CloudWatchMonitoringScripts-${VERSION}.zip"

 # Add monitoring scripts to crontab
COMMAND="/usr/bin/perl /home/hadoop/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --mem-used --mem-avail --disk-space-util --disk-path=/ --disk-path=/emr --disk-path=/mnt --disk-space-used --disk-space-avail"

CRON_SCHEDULE="*/1 * * * *"
 
echo "${CRON_SCHEDULE} ${COMMAND} --from-cron" > /etc/cron.d/1-cloudwatch