#!/bin/bash

#####################################################################
# Copyright (c) 2014 Stefan Jakobs
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#####################################################################

# Description
# This script can be used to do an offline backup (shutdown mysqld and
# zarafa-server) with snapshots on a NetApp vfiler

#### Set Environment ####
PATH="$PATH:/usr/bin/:/usr/sbin/:/bin:/sbin"
SSH='/usr/bin/ssh -o BatchMode=yes'
debug=${debug:-0}

zarafa_stop="debug=${debug} /usr/sbin/zarafa-safe-shutdown.sh"
zarafa_start="debug=${debug} /usr/sbin/zarafa-safe-start.sh"

declare -A vFiler_MA
declare -A vFiler_STUD

## souce configuratin file
source ${1:-'/etc/zarafa-offline-backup.cfg'}

#### Functions ####

node_prepare_backup() {
  local host="$1"

  if [ -z "$1" ]; then
     echo "error: no host to connect to!"
     echo 'error' > $error_file
     return 1;
  fi

  $SSH root@${host} $zarafa_stop
  if [ $? -ne 0 ]; then
     echo "${host}: error: failed to shutdown zarafa!"
     echo "${host}:        starting it again ..."
     $SSH root@${host} $zarafa_start
     if [ $? -ne 0 ]; then
        echo "${host}:  error: failed to start zarafa daemons again!"
     fi
     echo 'error' > $error_file
     return 1
  fi
}

node_start_zarafa() {
  local host="$1"

  if [ -z "$1" ]; then
     echo "error: no host to connect to!"
     echo 'error' > $error_file
     return 1;
  fi

  $SSH root@${host} $zarafa_start
  if [ $? -ne 0 ]; then
     echo "${host}: error: failed to start zarafa daemons again!"
     echo 'error' > $error_file
     return 1
  fi
}

check_return() {
   if [ $? -ne 0 ]; then
      echo "error: $1 failed!"
   fi
}

do_backup() {

   local nodes=$1
   e="$( declare -p $2 )"
   eval "declare -A vFiler=${e#*=}"

   ## get day of week
   local dow="$(date '+%a')"

   ## empty error file
   echo '' > $error_file

   for host in $nodes ; do
      node_prepare_backup $host &
   done
   ### wait for background jobs
   wait

   ## check error_file for errors
   read line < $error_file
   if [ "$line" == 'error' ]; then
      echo "error: node shutdown failed!"
      echo "error: skipped backup of ${nodes}!"
   else
      ## access all volumes of one vFiler_MA
      for vf in "${!vFiler[@]}" ; do
         for volume in ${vFiler[$vf]}; do
            o_del="$($SSH ${netapp_user}@${vf} snap delete ${volume} "${backup_name}-${dow}")"
            check_return "delete ${volume}"
            o_cre="$($SSH ${netapp_user}@${vf} snap create ${volume} "${backup_name}-${dow}")"
            check_return "backup ${volume}"
            if [ "$debug" != '0' ]; then
               echo $o_del
               echo $o_cre
               $SSH ${netapp_user}@${vf} snap list ${volume}
               check_return "list ${volume}"
            fi
         done
      done
   fi
  
   for host in $nodes ; do
      node_start_zarafa $host &
   done
   ### wait for background jobs
   wait

   ## check error_file for errors
   read line < $error_file
   if [ "$line" == 'error' ]; then
      echo "error: startup of ${nodes} failed!"
   fi
}

#### End of Functions ####

#### MAIN ####

## create a named pipe
error_file=$(mktemp -u)
if ! [ -e $error_file ]; then
   touch $error_file
fi

# remove $error_file if script exits
trap "rm -f $error_file" EXIT

## do backup
status_ma="$(do_backup "$nodes_ma" vFiler_MA)"
status_stud="$(do_backup "$nodes_stud" vFiler_STUD)"

if echo "$status_ma" | grep -q 'error' || echo "$status_stud" | grep -q 'error' ; then
   echo "$status_ma"
   echo "$status_stud"
else
   touch $status_file
   if [ "$debug" != '0' ]; then
      echo "$status_ma"
      echo "$status_stud"
   fi
fi

## remove error_file
rm -f $error_file

#### End of MAIN ####
