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
#
#####################################################################


declare -A LDAPURI
declare -A LDAPUSER
declare -A LDAPPW
declare -A LDAPBASE
declare -A ADMINCONF

LDAPURI['p']='ldaps://ldap.example.com:3269'
LDAPURI['q']='ldaps://ldap.staging.example.com:3269'
LDAPUSER['p']='CN=ldapqueryZarafa,OU=ServiceAccounts,DC=example,DC=com'
LDAPUSER['q']='CN=ldapqueryZarafa,OU=ServiceAccounts,DC=staging,DC=example,DC=com'
LDAPPW['p']='secret'
LDAPPW['q']='secret'
LDAPBASE['p']='dc=example=com'
LDAPBASE['q']='dc=staging,dc=example,dc=com'
ADMINCONF['p']='/etc/zarafa/admin.prod.cfg'
ADMINCONF['q']='/etc/zarafa/admin.staging.cfg'

_filter='^(mail|otherMailbox):'
_env='p'
_querystring=''
_mail=''
_detail='0'

usage() {
   echo "$0 [-d] [-Q] -m <email address> |" 
   echo "  ( -a <sAMAccountName> | -s <surName> | -g <givenName> [-f <filter>] )"
   echo
}

while getopts "a:f:g:m:s:dQ?h" opt; do
  case $opt in
    a)
      _querystring="$OPTARG"
      _attribute='sAMAccountName'
      ;;
    m)
      _mail="$OPTARG"
      ;;
    f)
      _filter="$OPTARG"
      ;;
    g)
      _querystring="$OPTARG"
      _attribute='givenName'
      ;;
    s)
      _querystring="$OPTARG"
      _attribute='sn'
      ;;
    d)
      _details="$(( $_details + 1 ))"
      ;;
    Q)
      _env='q'
      ;;
    \?|h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [ -n "$_querystring" ]; then
   result="$(ldapsearch -H ${LDAPURI["$_env"]} -D ${LDAPUSER["$_env"]} -b ${LDAPBASE["$_env"]} \
          -w ${LDAPPW["$_env"]} "(${_attribute}=${_querystring})" )"
   if [[ "$_details" -gt '0' ]]; then
      echo "#### LDAP RESULT START ####"
      echo "$result" | tail -n +9
      echo -e "#### LDAP RESULT END ####\n"
   fi
   echo
   echo "$result" | egrep -i $_filter # | awk '{ print $2 }'
elif [ -n "$_mail" ]; then
   result="$(ldapsearch -H ${LDAPURI["$_env"]} -D ${LDAPUSER["$_env"]} -b ${LDAPBASE["$_env"]} \
          -w ${LDAPPW["$_env"]} "(|(othermailbox=${_mail})(mail=${_mail}))" )"
   if [[ "$_details" -gt '0' ]]; then
      echo "#### LDAP RESULT START ####"
      echo "$result" | tail -n +9
      echo -e "#### LDAP RESULT END ####\n"
   fi
   account="$(echo "$result" | grep -i 'sAMAccountName' | awk '{ print $2 }')"
   if [ -z "$account" ]; then
      echo "error: can not find '$_mail'"
      echo
   else
      for user in $account ; do
         zarafa-admin --config "${ADMINCONF["$_env"]}" --details $user
      done
   fi
else
   usage
   exit 1
fi

