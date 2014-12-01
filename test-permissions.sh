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
while read permissions rest; do

   if [[ "$permissions" =~ ^lrs?w?ip?cda$ ]]; then
      printf "%-10s owner\n" $permissions
   elif [[ "$permissions" =~ ^lrs?w?ip?cd$ ]]; then
      printf "%-10s fullcontrol\n" $permissions
   elif [[ "$permissions" =~ ^(lrs?w?ip?(d|c)|lrs?w?p?cd)a?$ ]]; then
      printf "%-10s secretary\n" $permissions
   elif [[ "$permissions" =~ ^l?rs?w?i?p?(c|d|a)?$ ]]; then
      printf "%-10s read only\n" $permissions
   elif [[ "$permissions" =~ ^ls?w?p?$ ]]; then
      printf "%-10s no rights\n" $permissions
   else
      printf "%-10s don't migrate\n" $permissions
   fi

done
