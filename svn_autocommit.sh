#!/bin/bash

# Check first if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   echo "Run the following command then 'chmod u+x svn_autocommit.sh'"
   exit 1
fi

# Working space and credentials
svn_wk='/var/www/bos-cga-fc1.thinkingphones.com/audiocodes'
svn_user='root'
svn_passwd='kn1cker5'

# Defining the time parameters and the SVN app directory
date=`/bin/date +"%F %T"`
svn='/usr/bin/svn'

# Check the status of the folder, delete, add, update and finally commit again
script_path=`dirname $(readlink -f $0)`
cd $svn_wk

#run svn update first
svn_log='/var/log/svn-autocommit.log'

# time to begin this...

stat=`svn status`

if [[ $stat != '' ]]; then
        # Are there any files to delete?
        delete_files=`echo $stat|grep '^\!'|sed 's/\! / /g'`
        if [[ $delete_files != '' ]]; then
                for file in $delete_files; do
                        svn delete $file >> $svn_log
                done
        fi

        # Are there any files to add?
        add_files=`echo $stat|grep '^\?'|sed 's/\? / /g'`
        if [[ $add_files != '' ]]; then
                for file in $add_files; do
                        svn add $file >> $svn_log
                done
        fi
        # Do an update again
        $svn update --username $svn_user --password $svn_passwd --non-interactive >> $svn_log
        # Finaly commit
        $svn commit -m "$date - Automatic commits" --username $svn_user --password $svn_passwd --non-interactive >> $svn_log
fi
