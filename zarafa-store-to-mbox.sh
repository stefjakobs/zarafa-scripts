#!/bin/bash

#####################################################################
# Copyright (c) 2014 Stefan Jakobs <projects AT localside.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
#####################################################################

HOME_SERVER_PREFIX='https://'
HOME_SERVER_SUFFIX=".${HOSTNAME#*.}"
IMAP_SERVER='imap.example.com'
ZARAFA_PORT='237'

HELP_TEXT=$( cat <<- EOT
	$0 -s <source user> -d <dest user>
	   [-H <zarafa server>] [-I <zarafa imap server>]
	   [-P <home server prefix>] [-S <home server suffix>]
	   [-p <zarafa port>]
	   [-c <zarafa-backup cfg file>]
	   [-o <output directory> ]
	   [-h|-?]
EOT
)

function usage {
   echo "$HELP_TEXT"
   exit 1
}

function man_usage {
   echo "$HELP_TEXT"
   cat <<-EOT
	
	This script will perform a complete backup of an user's (source user)
	data store and will then restore this 'brick level backup' to an other
	user's (destination user) data store. Finally it will pull every item
	via IMAP and store the items in one mbox file for each folder.

	To find the users home servers this script will connect to the zarafa
	server named by the option -H <zarafa server>.

	The zarafa-backup utility needs a configuration file which is per
	default /etc/zarafa/backup.cfg. An other one can be used with the
 	option -c <zarafa-backup cfg file>.

	The brick level backup files (index.zbk and data.zbk) will be stored in
	the current working directory or in the directory named with the option
	-o <output directory>.

	Finally all items will be fetched from an IMAP server (default: $IMAP_SERVER).
	Another one can be used by using the option -I <imap server>.

	To access the users home server, the script will build the URL from the
	home server name, the home server prefix and suffix and Zarafa's port number:
	   <home server prefix><home server><home server suffix>:<zarafa port>
	The default is:
	   ${HOME_SERVER_PREFIX}\$HOME_SERVER${HOME_SERVER_SUFFIX}:${ZARAFA_PORT}

	All mbox files will be bundled in a gzipped tar archive in the CWD or 
	the output directory named by the option -o.

EOT
   exit 1
}

function get_home_server {
   user="$1"
   if [ -z "$user" ]; then
      echo "error: function get_home_server failed!"
      exit 1
   fi
   
   # get the users home server
   home_server=$(zarafa-admin --host $ZHOST --details $user | grep "Home server:" | awk '{ print $3 }')
   if [ $? -ne 0 -o -z "$home_server" ]; then
      echo "error: can not find users ($user) home server!"
      exit 1
   fi
   HOME_SERVER="${HOME_SERVER_PREFIX}${home_server}${HOME_SERVER_SUFFIX}${ZARAFA_PORT:+:}${ZARAFA_PORT}"
}

while getopts '?hc:d:H:I:P:S:o:p:s:t:' opt; do
   case $opt in
      's') 
         SRC_USER="$OPTARG" ;;
      'd')
         DEST_USER="$OPTARG" ;;
      'H')
         ZHOST="$OPTARG" ;;
      'I')
         IMAP_SERVER="$OPTARG" ;;
      'P')
         HOME_SERVER_PREFIX="$OPTARG" ;;
      'S')
         HOME_SERVER_SUFFIX="$OPTARG" ;;
      'c')
         ZBACKUP_CFG="$OPTARG" ;;
      'o')
         OUTPUT_DIR="$OPTARG" ;;
      'p')
         ZARAFA_PORT="$OPTARG" ;;
      'h'|'?')
         man_usage ;;
      *)
         usage ;;
   esac
done

## Debug
#echo "from:       $SRC_USER"
#echo "to:         $DEST_USER"
#echo "zhost:      $ZHOST"
#echo "backup cfg: $ZBACKUP_CFG"
#echo "output dir: $OUTPUT_DIR"

## source and destination users are mandatory
if [ -z "$SRC_USER" -o -z "$DEST_USER" ]; then
   usage
fi
## use local socket if no zarafa server was named
if [ -z "$ZHOST" ]; then
   ZHOST='file:///var/run/zarafa'
fi
## set default value for zarafa-backup config file
if [ -z "$ZBACKUP_CFG" ]; then
   ZBACKUP_CFG='/etc/zarafa/backup.cfg'
fi
## check if zarafa-backup config file is readable
if [ ! -r "$ZBACKUP_CFG" ]; then
   echo "error: can not read zarafa-backup config file ($ZBACKUP_CFG)!"
   exit 1
fi
## use given output dir or use cwd
if [ -z "$OUTPUT_DIR" ]; then
   OUTPUT_DIR=$PWD
fi
if [ ! -d "$OUTPUT_DIR" -a ! -w "$OUTPUT_DIR" ]; then
   echo "error: can not enter or write into $OUTPUT_DIR !"
   exit 1
fi

## check if zarafa binaries are executable
for binary in zarafa-admin zarafa-restore zarafa-backup imapbackup.py; do
   if [ ! -x "$(which $binary)" ]; then
      echo "error: can not execute $binary !"
      exit 1
   fi
done

#### BACKUP #### 

# get the users home server
get_home_server $SRC_USER 

# do the backup
if ! zarafa-backup -u "${SRC_USER}" -c "${ZBACKUP_CFG}" \
                   -h "${HOME_SERVER}" -o "${OUTPUT_DIR}" ; then
   echo "error: zarafa-backup failed!"
   exit 1
fi


#### RESTORE ####
index="${OUTPUT_DIR}/${SRC_USER}.index.zbk"

## check if index file is accessible
if [ ! -r "$index" ]; then
   echo "error: can not read $index"
   exit 1
fi

index_root=`head -2 "${index}" | grep ^R | cut -d\: -f3`
if [ -z "${index_root}" ]; then
	echo 'error: Root entry not found in index!'
	exit 1
fi

# get the users home server
get_home_server $DEST_USER 

## zarafa-restore search for the index file in the cwd; 
pushd "$OUTPUT_DIR" > /dev/null
# The options '-i -' makes the zarafa-restore tool read the restore keys from stdin
grep ^C "${index}" | grep ${index_root} | cut -d\: -f7 | \
   zarafa-restore -c "${ZBACKUP_CFG}" \
                  -f "${SRC_USER}" \
                  -u "${DEST_USER}" \
                  -h "${HOME_SERVER}" -r -v -i -
if [ "$?" -ne 0 ]; then
   echo "error: restore failed!"
   popd > /dev/null
   exit 1
fi
popd > /dev/null


#### CREATE MBOX FILES ####
TMPDIR=$(mktemp -d)
mkdir "${TMPDIR}/${SRC_USER}"

## imapbackup.py will store the mbox files in the cwd
pushd "${TMPDIR}/${SRC_USER}" > /dev/null
echo "I'm now in $PWD"
echo "Enter IMAP passwort for user ${DEST_USER}:"
if ! imapbackup.py -e -s "$IMAP_SERVER" -u $DEST_USER ; then
   echo "error: imap backup failed!"
fi

## make a tar file with a relative path
cd "${TMPDIR}"
if ! tar czf "${OUTPUT_DIR}/${SRC_USER}.backup.tar.gz" "$SRC_USER" ; then
   echo "error: failed to create tarball!"
   echo "       mbox files are located in $TMPDIR"
else
   rm -r "$TMPDIR"
   echo
   echo "success: mbox files located in ${OUTPUT_DIR}/${SRC_USER}.backup.tar.gz"
fi
popd > /dev/null

