#!/bin/sh

# Country IP Address Filter is used to deny or accept all IP
# addresses from certain countries.
# It should be ran after the system has started up because
# the ipset sets and the iptables rules do not survive a reboot.
# It should also be ran periodically to update the country IP
# sets from ipdeny.com.

# change current working directory to where this script is located
cd "$( dirname "${BASH_SOURCE}" )"

# loop through the accept directory looking for country shell scripts to execute
for file in $( ls -1 *.sh | grep -v -e country-ip-filter.sh -e filter-country.sh )
do
    ./$file
done
