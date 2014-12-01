#!/bin/bash

#####################################################################
# Copyright (c) 2014 Stefan Jakobs <projects AT localside.net>
#####################################################################
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
######################################################################

# Description:
# Get a list of orphan users and report/remove all those users
# which date of last login is older than e.g. six month

# Remove stores not on the first run. Instead create a list of stores
# to remove linked with a date when to remove each store.
# On every run read that list and check if a listed account is still
# orphaned, check the date to remove and if necessary remove that
# account. Otherwise keep that account on that list and generate a 
# new list.


##### GLOBAL VARIABLES & FUNCTIONS #####

# set defaults
KEEP_TIME=$(( 6*30*24*60*60 ))   # six month in seconds
REMOVE_STORES=0
VERBOSE=0
DEBUG=0
STORES_TO_REMOVE='/etc/zarafa/zarafa-stores-to-remove'
SAFETY_TIME=$(( 7*24*60*60 )) # one week in seconds

function usage {
   echo "$0 [-h|-?] [-d [-d]] [-R] [-v] [-k seconds] [-L /stores/to/remove]"
   echo "   [-S seconds]"
   echo
}

function get_help {
   usage
   echo "   -d       ... turn debug mode on (add twice to increase verbosity)"
   echo "   -v       ... verbose output; print states of stores"
   echo "   -R       ... remove stores without further questions"
   echo "   -k secs  ... keep stores which last login date is not older than <secs> seconds"
   echo "   -L /path ... file which contains a list of users and their date to remove"
   echo "   -S secs  ... time after which a store will be removed"
   echo "   -h|-?    ... print this help message"
   echo
}

function list_stores {
   if [ -z "$1" ] || [ -z "$2" ]; then
      echo "error: list_stores(): not enough arguments!"
   else
      local guid="$1"
      local state="$2"
      printf "$format" "$guid" "${users[$guid]}" \
         "$(date -d @${logins[$guid]} +'%D %T')" "($(( $now - ${logins[$guid]} )))"  "$state"
   fi
}

##### PREPARE #####

declare -A users
declare -A logins
declare -A remove_dates
declare -a remove_stores
declare -a keep_stores
declare -a new_stores

format='%-32s  %-8s  %-18s  %-12s  %-8s\n'

while getopts '?dhk:vL:RS:' opt; do
   case $opt in
      'd')
         DEBUG=$(( $DEBUG + 1 )) ;;
      'R')
         REMOVE_STORES=1 ;;
      'v')
         VERBOSE=1 ;;
      'h'|'?')
         get_help
         exit 0
         ;;
      'k')
         KEEP_TIME="$OPTARG"
         ;;
      'S')
         SAFETY_TIME="$OPTARG"
         ;;
      'L')
         STORES_TO_REMOVE="$OPTARG"
         ;;
      *)
         usage
         exit 1
         ;;
   esac
done

## check options
if ! [[ "$KEEP_TIME" =~ ^[0-9]+$ ]]; then
   echo "error: option '-k' expects a number"
   exit 1
fi
if ! [[ "$SAFETY_TIME" =~ ^[0-9]+$ ]]; then
   echo "error: option '-S' expects a number"
   exit 1
fi
if ! [ -a "$STORES_TO_REMOVE" ]; then
   if ! touch "$STORES_TO_REMOVE" 2>/dev/null ; then
      echo "error: can not create $STORES_TO_REMOVE."
      exit 1
   fi
elif ! [ -w "$STORES_TO_REMOVE" ]; then
   echo "error: can not write $STORES_TO_REMOVE"
   exit 1
fi

## set variables which depend on options
now="$(date +%s)"
latest_login_to_remove="$(( $now - $KEEP_TIME ))"

##### MAIN #####

## read in stores to remove
# file has the following format:
# store_guid date_to_remove_in_seconds_since_1970
while read guid remove_date ; do
   if [ -z "$guid" ] || [ -z "$remove_date" ]; then
      echo "error: data set in $STORES_TO_REMOVE has wrong format. Will skip it."
      continue
   fi
   remove_dates[$guid]="$remove_date"
   if [[ "$DEBUG" -ge 2 ]]; then
      echo "read \"$guid $remove_date\" from file: $STORES_TO_REMOVE"
   fi
done < "$STORES_TO_REMOVE"

## read in list of orphaned stores
while read guid user date time rest ; do
   if [ -z "$guid" ]; then
      [[ "$DEBUG" -ge 1 ]] && echo "debug: guid is empty. Assuming end of data."
      break
   fi
   if [[ "$date" = '<unknown>' ]]; then
      last_login="@${latest_login_to_remove}"
   else
      last_login="$date $time"
   fi
   users[$guid]="$user"
   logins[$guid]="$(date -d "$last_login" +%s)"

   if [ ${logins[$guid]} -le $latest_login_to_remove ]; then
      # old enough to consider for deletion
      if [ -z "${remove_dates[$guid]}" ]; then
         # not listed for deletion; set it on list
         remove_dates[$guid]="$now"
         new_stores=("${new_stores[@]}" "$guid")
      elif [ "${remove_dates[$guid]}" -ge "$(( $now - $SAFETY_TIME ))" ]; then
         # listed for deletion, but has not yet reached due date
         keep_stores=("${keep_stores[@]}" "$guid")
      else
         # listed for deletion
         remove_stores=("${remove_stores[@]}" "$guid")
      fi
   else
      # not old enough to consider for deletion
      true
   fi
done <<< "$(LANG=C zarafa-admin --list-orphans | tail -n +4)"

# clean up list of remove_dates
for guid in ${!remove_dates[@]}; do
   if [[ -z "${users[$guid]}" ]]; then
      # store isn't orphan any more; remove from list.
      unset remove_dates[$guid]
      [[ "$DEBUG" -ge 2 ]] && echo "debug: $guid is not orphaned any longer. Remove from list."
   fi
done

# print output
if [[ "$REMOVE_STORES" -eq 1 ]];then
   do_what='Delete'
else
   do_what='Report'
fi

if [[ "$VERBOSE" -eq 1 ]]; then
   echo "$do_what all orphan stores which date of last login is older than:"
   echo "   $(date -d @${latest_login_to_remove}) ($latest_login_to_remove)"
   echo "and which have been marked for deletion for more than $SAFETY_TIME seconds"
   echo
   if [[ "$DEBUG" -ge 1 ]]; then
      for guid in ${new_stores[@]}; do
         list_stores "$guid" 'new'
      done
      for guid in ${keep_stores[@]}; do
         list_stores "$guid" 'keep'
      done
   fi
   for guid in ${remove_stores[@]}; do
       list_stores "$guid" 'REMOVE'
   done
fi

# remove stores if requested
if [[ "$REMOVE_STORES" -eq 1 ]]; then
   for guid in ${remove_stores[@]}; do
      if [[ "$VERBOSE" -eq 1 ]] || [[ $DEBUG -ge 1 ]]; then
         echo -n "zarafa-admin --remove-store $guid   ... "
      fi
      # if zarafa-admin --remove-store $guid >/dev/null ; then
      if echo zarafa-admin --remove-store $guid >/dev/null ; then
         if [[ "$VERBOSE" -eq 1 ]] || [[ $DEBUG -ge 1 ]]; then
            echo "OK"
            if [[ $DEBUG -ge 1 ]]; then
               echo "    Store $guid of ${users[$guid]} with last login at $last_login successfully removed"
            fi
         fi
         unset remove_dates[$guid]
      else
         if [[ "$VERBOSE" -eq 1 ]]; then
            echo "failed"
         else
            echo "failed to remove store $guid of $user on $HOSTNAME"
         fi
      fi
   done
fi

# export new list of stores marked to remove
_temp="$(mktemp)"
for guid in ${!remove_dates[@]}; do
   echo "$guid ${remove_dates[$guid]}" >> "$_temp"
   if [[ "$DEBUG" -ge 2 ]]; then
      echo "writing \"$guid ${remove_dates[$guid]}\" to file: $_temp"
   fi
done
if ! mv "$_temp" "$STORES_TO_REMOVE"; then
   echo "error: could not store new list of stores to remove!"
   exit 1
fi
