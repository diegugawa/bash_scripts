#!/bin/env bash

# Working space and credentials
svn_wk='/tmp/svn_workspace'
svn_user='foo'
svn_passwd='bar'

# Defining the time parameters and the SVN app directory
date=$( /bin/date '+%Y-%m-%d %H:%M:%S' )
SVN='/usr/bin/svn'
stat="${SVN} status -u"
svn_log='/var/log/svn-autocommit.log'

delete_files=$(${stat}|grep '^\!'|sed 's/\! / /g')
add_files=$(${stat}|grep '^\?'|sed 's/\? / /g')
modify_files=$(${stat}|grep '^\*'|sed 's/\* / /g')

# Start in the SVN directory first
cd $svn_wk || exit

# Check first if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   echo "Run the following command 'chmod 0644 svn_autocommit.sh'"
   exit 1
fi

# Check the status of the folder, delete, add, update and finally commit again

# Are there any files to delete?
if [[ $stat != '' ]]; then
      if [[ $delete_files != '' ]]; then
        for file in $delete_files; do
          "${SVN} delete $file >> $svn_log"
        done
      fi

# Are there any files to add?
if [[ $add_files != '' ]]; then
  for file in $add_files; do
    "${SVN} add $file >> $svn_log"
  done
fi

# Do an update again
$SVN update --username $svn_user --password $svn_passwd --non-interactive >> $svn_log
# Finaly commit
$SVN commit -m "$date - Automatic commits" --username $svn_user --password $svn_passwd --non-interactive >> $svn_log
# Print when this was updated        
 echo "Repository updated on $date" >> $svn_log
fi

if [[ $stat != '' ]]; then
  # Are there any files to modify?
  if [[ $modify_files != '' ]]; then
    for file in $modify_files; do
      ${SVN} up $file >> $svn_log
    done
  fi
fi
