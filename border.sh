#!/bin/bash

# Working space and credentials
svn_wk='/var/www/bos-cga-fc1.thinkingphones.com/audiocodes'
svn_user='root'
svn_passwd='kn1cker5'

# Defining the time parameters and the SVN app directory
date=`date '+%Y-%m-%d %H:%M:%S'`
svn='/usr/bin/svn'

# Check the status of the folder, delete, add, update and finally commit again
script_path=`dirname $(readlink -f $0)`

# This is the SVN log file
svn_log='/var/log/svn-autocommit.log'

# Defining SVN status
stat=`svn status -u $svn_wk`

# DB settings. I'm aware this is not best practices... but it's a hack, so move it to a separate file when you can.
user_db='dps_read_user'
pass_db='HrFQcOFHyQrK'
server_db='cam-db1a-ng.tpn.thinkingphones.net'

# find the Proxyname string and filter it
filter_pbx=`grep -E "PROXYNAME =" $1`
pbx="$(echo $filter_pbx | cut -d = -f 2 | sed -e "s/'//g" | cut -d . -f 1 | sed -e 's/ //g')"

# Query the ocp DB and finds the border proxy if any
sql_query_bpname="$(echo $pbx | mysql -u $user_db -p$pass_db -h $server_db -BN -e "SELECT sip_proxy FROM ocp.pbx_settings WHERE context = '$pbx'" 2>&1 | grep -v "Warning: Using a password")"

# Query the ocp DB and finds if there border proxy is enabled or not
sql_query_bpstatus="$(echo $pbx | mysql -u $user_db -p$pass_db -h $server_db -BN -e "SELECT use_border_proxy FROM ocp.pbx_settings WHERE context = '$pbx'" 2>&1 | grep -v "Warning: Using a password")"

# Based on the finds, then start making changes
change_bp="$(echo $sql_query_bpname | sed -i "s/$pbx.thinkingphones.net/$sql_query/g")"

# The below changes to DNS if that is required
change_dns="$(echo $sql_query_bpstatus | sed -i "s/DNSQUERYTYPE = 1/DNSQUERYTYPE = 2/g")"


# Function below queries for the BP. If there is nothing to change, then skip that too.
find_bp () {
  if [ $filter_pbx != '' ]; then
    $sql_query_bpname;
  else
      return 0;
      echo "Couldn't find anything in the DB. Nothing to change" >> $svn_log;
  fi;
}

# Change values to BP and DNS based on the PBX
change_to_bp_values () {
    if [ $sql_query_bpstatus == 1 ]; then
      $change_bp $1;
      $change_dns $1;
    else
      return 0
      echo "There wasn't anything to change" >> $svn_log;
    fi;
}

svn_add () {
    if [ $stat != '' ]; then
        # Are there any files to add and change?
        add_files=`echo $stat|grep '^\?'|sed 's/\? / /g'`
        if [[ $add_files != '' ]]; then
                for file in $add_files; do
                  find_bp;
                  change_to_bpvalues;
                  svn add $file>/dev/null 2>/dev/null;
                  svn commit --username $svn_user --password $svn_passwd --non-interactive -m "$date - Automatic commits" $file >> $svn_log;
                done;
        fi;
    fi;
}

svn_delete () {
    if [ $stat != '' ]; then
        # Are there any files to delete?
        delete_files=`echo $stat|grep '^\!'|sed 's/\! / /g'`
        if [ $delete_files != '' ]; then
                for file in $delete_files; do
                        svn delete $file>/dev/null 2>/dev/null;
                        svn commit --username $svn_user --password $svn_passwd --non-interactive -m "$date - Automatic commits" $file >> $svn_log;
                done;
        fi;
    fi;
}

svn_update () {
  if [ $stat != '' ]; then
        # Are there any files to modify?
        modify_files=`echo $stat|grep '^\*'|sed 's/\* / /g'`
        if [ $modify_files != '' ]; then
                for file in $modify_files; do
                        svn up $file>/dev/null 2>/dev/null;
                        svn commit --username $svn_user --password $svn_passwd --non-interactive -m "$date - Automatic commits" $file >> $svn_log;
                done;
        fi;
  fi;
}

# Main Function that calls it all
svn_w_bp () {
  if [[ $EUID -ne 0 ]]; then
     echo "This script must be run as root"
     echo "Run the following command 'chmod 644 svn_autocommit.sh'"
     exit 1
   else
    if [ ! -e $svn_wk ]; then
      svn_add;
      svn_delete;
      svn_update;
    fi;
  fi;
}
