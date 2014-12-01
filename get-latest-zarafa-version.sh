#!/bin/bash

latest_zcp_version=0
latest_zcp_build=0
latest_client_version=0
latest_client_build=0

old_zcp_version=0
old_client_version=0

major='7.1'
url="http://download.zarafa.com/community/final/${major}/"

state_file="${HOME}/.latest_zarafa_version.conf"

if [ -r "$state_file" ]; then
   source "$state_file"
elif ! touch "$state_file" ; then
   echo "error: can not touch $state_file !"
   exit 1
fi

## check ZCP version ##
zcp_versions="$(wget -O - "${url}" 2>/dev/null | \
   cut -d'>' -f7 | cut -d'<' -f1 | tr -d '/' | grep -v '^$' | \
   egrep -v 'Parent Directory|final-changelog')"

IFS='-'
while read version build; do
   if [[ $build -gt $latest_build ]]; then
      latest_build=$build
      latest_version=$version
   fi
done <<< "$zcp_versions"


## check OL client version ##
client_versions="$(wget -O - "${url}${latest_version}-${latest_build}/windows/" 2>/dev/null | \
   cut -d'>' -f7 | cut -d'<' -f1 | tr -d '/' | grep 'zarafaclient' )"

IFS='-'
while read client version build ; do
   build=${build%.msi}
   if [[ $build -gt $latest_client_build ]]; then
      latest_client_build=$build
      latest_client_version=$version
   fi
   #echo "$client  $version  ${build%.msi}}"
done <<< "$client_versions"

if [ "$old_zcp_version" != "${latest_version}-${latest_build}" ] || \
   [ "$old_client_version" != "${latest_client_version}-${latest_client_build}" ]; then
   echo "old_zcp_version=${latest_version}-${latest_build}" > $state_file
   echo "old_client_version=${latest_client_version}-${latest_client_build}" >> $state_file
   echo "NEW ZARAFA UPDATE:"
   echo "latest zcp version:    ${latest_version}-${latest_build}"
   echo "latest client version: ${latest_client_version}-${latest_client_build}"
fi

