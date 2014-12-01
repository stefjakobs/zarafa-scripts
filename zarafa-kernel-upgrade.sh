#!/bin/bash

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

QS=".qs"

usage() {
   echo "$0 [-p|-q]"
   exit 1
}

if [ -n "$1" ]; then 
   case "$1" in
      '-p') QS=''
            ;;
      '-q') QS='.qs'
            ;;
      *)    usage
            ;;
   esac
else
   usage
fi

echo "Performing kernel and vmmodules upgrade of ${QS:-.prod} system:"
echo

for host in mail-znode-{stud,ma}{1,2,3}${QS} mail-gateway{1,2}${QS} mail-web{1,2,3}${QS} mail-autoconfig${QS} ; do
   echo "${host}:"
   ssh root@${host} "sed -i 's/debfoster -f/true/' /root/bin/upgrade-kernel-and-vmmodules"
   ssh root@${host} /root/bin/upgrade-kernel-and-vmmodules
   #ssh root@${host} rm /etc/nagios/obsolete-packages-ignore.d/ignore-openvm-modules.conf.dpkg-old
done
