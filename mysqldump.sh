# !/bin/bash

# Check first if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   echo "Run the following command then 'chmod 0644 svn_autocommit.sh'"
   exit 1
fi

# This is a simple script to backup the DB for the CGA by running mysqldump,
# then compresses the file and it does a push to the master branch in Github

# Variables
DBNAME='cga'
DBUSER='root'
DBPASS='think123'
DBHOST='localhost'
DATE=`date +"%Y%m%d"`
SQLFILE="$DBNAME-${DATE}.sql"
SQLLOG='/var/log/mysqldump.log'

# in case this is run this more than once a day, remove the previous version of the file
cd /tmp/cga_mysqldump
unalias rm     2> /dev/null
rm ${SQLFILE}     2> /dev/null
rm ${SQLFILE}.gz  2> /dev/null

# What to run
mysqldump -u$DBUSER -p$DBPASS -h$DBHOST -B $DBNAME > /tmp/cga_mysqldump/$SQLFILE
gzip /tmp/cga_mysqldump/$SQLFILE
echo "CGA mysqldump ${SQLFILE} backup completed" >> $SQLLOG
