#!/bin/bash

# Copyright (c) 2014 Stefan Jakobs
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
#####################################################################
# 
# Description:
# This script creates a new store for all users of a company.
# If no company is named it creates stores for all users

IGNORE='Username|SYSTEM|-------|^User list|^$'
IGNORE_ORPHANS='^Stores without users|^Users without stores|-------|Username|Store guid|^$'

HELP_TEXT=$( cat <<- EOT
   $0 
      [-c <company> | -o]
      [-H <zarafa server>]
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
   
   This script will create a store for every user in a company,
   if named. Or for all users with no store (-o).
   Otherwise for every user on the system.
EOT
   exit 1
}

while getopts '?hoc:' opt; do
   case $opt in
      'H')
         ZHOST="--host $OPTARG" ;;
      'c')
         COMPANY="-I \"$OPTARG\"" ;;
      'o')
         ORPHANS="--list-orphans" ;;
      'h'|'?')
         man_usage ;;
      *)
         usage ;;
   esac
done

while read user node; do
   zarafa-admin --create-store $user --node $node;
done <<< "$(
if [ -n "$COMPANY" ]; then
   zarafa-admin -l $COMPANY | egrep -v "$IGNORE" |awk '{ print $1 " "$NF; }';
elif [ -n "$ORPHANS" ]; then
   while read user ; do
      zarafa-admin -l | egrep -v "$IGNORE" |awk '{ print $1 " "$NF; }';
   done <<< $(zarafa-admin $ORPHANS | egrep -v "$IGNORE_ORPHANS" |awk '{ print $1 " "$NF; }');
else
   zarafa-admin -l | egrep -v "$IGNORE" |awk '{ print $1 " "$NF; }';
fi
)";
 
echo "finished!"
