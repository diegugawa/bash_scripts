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
stat=`svn status $svn_wk`

# DB settings. I'm aware this is not best practices... but it's a hack, so move it to a separate file when you can.
user_db='dps_read_user'
pass_db='HrFQcOFHyQrK'
server_db='cam-db1a-ng.tpn.thinkingphones.net'

# Creating extra file for not parsing the password into the file
#extra_file="$(mktemp)";
#cat > extra_file << EOF
#[client]
#password=${pass_db}
#EOF
# ^^^^The above doesn't work because needs mysql 5.6 or later :(

# Defining Mysql call using just caps
MYSQL="mysql -u ${user_db} -p${pass_db} -h ${server_db}"


# Function below queries for the BP.
# parameters
# - input_file
find_and_change_bp () {
  local input_file="${1}";
  if [ -z "${input_file}" ]; then
    echo "ERROR: ${FUNCNAME}:  require input file as first parameter";
    exit 1;
  fi;

  # find the Proxyname string and filter it
  local filter_pbx="$(grep -E "PROXYNAME =" ${input_file})"

  # if there is no PROXNAME line, skip
  if [ -z "${filter_pbx}" ]; then
    echo "INFO: input file: ${input_file} did not have PROXYNAME line, not doing anything." >> ${svn_log};
    return 0;
  fi;

  local pbx="$(echo ${filter_pbx} | cut -d = -f 2 | sed -e "s/'//g" | cut -d . -f 1 | sed -e 's/ //g')"
  if [ -z "${pbx}" ]; then
    echo "INFO: unable to determine PBX from PROXNAME: ${filter_pbx} in input_file ${input_file}, nothing to change" >> ${svn_log};
    return 0;
  fi;

  # Query the ocp DB and finds if there border proxy is enabled or not
  # The result will be a '1' or a '0'
  echo "INFO: querying ocp database to see if PBX ${pbx} uses a border proxy..." >> ${svn_log};
  local sql_query_bpstatus="$(${MYSQL} -BN -e "SELECT use_border_proxy FROM ocp.pbx_settings WHERE context = '${pbx}'" 2>&1 | grep -v "Warning: Using a password")";
  if [ ${?} -ne 0 ]; then
    echo "ERROR: Unable to invoke use_border_proxy query.";
    return 1;
  fi;
  echo "INFO: PBX ${pbx} use a border proxy: ${sql_query_bpstatus}" >> ${svn_log};

  if [ "${sql_query_bpstatus}" == "1" ]; then

    # Query the ocp DB and finds the border proxy if any
    echo "INFO: querying ocp database sip_proxy ..." >> ${svn_log};
    local sql_query_bpname="$(${MYSQL} -BN -e "SELECT sip_proxy FROM ocp.pbx_settings WHERE context = '${pbx}'" 2>&1 | grep -v "Warning: Using a password")";
    if [ ${?} -ne 0 ]; then
      echo "ERROR: Unable to invoke sip_proxy query." >> ${svn_log};
      return 1;
    fi;
    echo "INFO: PBX ${pbx} uses border proxy: ${sql_query_bpname}." >> ${svn_log};

    if [ ! -z "${sql_query_bpname}" ]; then
      # there was a border proxy found from the sql query.
      sed -i "s/${pbx}.thinkingphones.net/${sql_query_bpname}/g" ${input_file};
      sed -i "s/DNSQUERYTYPE = 1/DNSQUERYTYPE = 2/g" ${input_file};
    fi;

  fi;
}


svn_add () {
    if [[ $stat != '' ]]; then
        # Are there any files to add and change?
        add_files=`echo $stat|grep '^\?'|sed 's/\? / /g'`
        if [[ $add_files != '' ]]; then
                for file in $add_files; do
                  find_and_change_bp ${file};
                  svn add $file>/dev/null 2>/dev/null;
                  svn commit --username $svn_user --password $svn_passwd --non-interactive -m "$date - Automatic commits" $file >> $svn_log;
                done;
        fi;
    fi;
}

svn_delete () {
    if [[ $stat != '' ]]; then
        # Are there any files to delete?
        delete_files=`echo $stat|grep '^\!'|sed 's/\! / /g'`
        if [[ $delete_files != '' ]]; then
                for file in $delete_files; do
                        svn delete $file>/dev/null 2>/dev/null;
                        svn commit --username $svn_user --password $svn_passwd --non-interactive -m "$date - Automatic commits" $file >> $svn_log;
                done;
        fi;
    fi;
}

svn_update () {
  if [[ $stat != '' ]]; then
        # Are there any files to modify?
        modify_files=`echo $stat|grep '^\*'|sed 's/\* / /g'`
        if [[ $modify_files != '' ]]; then
                for file in $modify_files; do
                        svn up $file>/dev/null 2>/dev/null;
                        svn commit --username $svn_user --password $svn_passwd --non-interactive -m "$date - Automatic commits" $file >> $svn_log;
                done;
        fi;
  fi;
}

# Main Function that calls it all
svn_bp () {
  if [[ $EUID -ne 0 ]]; then
     echo "This script must be run as root"
     echo "Run the following command 'chmod 644 svn_autocommit.sh'"
     exit 1
   else
    if [[ -e $svn_wk ]]; then
      svn_add;
	     sleep 1;
      svn_delete;
	     sleep 1;
      svn_update;
	     sleep 1;
    fi;
  fi;
}

##
# Start the script
##
svn_bp;
