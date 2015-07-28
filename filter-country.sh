#!/bin/sh

if [[ -z $country_name || -z $country_code || -z $country_target ]]
then
    echo "This script requires the following variables to be defined:"
    echo "\$country_name, used to name the ip set"
    echo "\$country_code, 2-letter ISO"
    echo "\$country_target, this can be ACCEPT, DROP or REJECT"
    exit 1
fi

# download aggregated zone file
wget --no-verbose --timestamping \
http://www.ipdeny.com/ipblocks/data/aggregated/$country_code-aggregated.zone
if [ $? -ne 0 ]
then
    exit 1
fi

# delete temporary country set if it exists
ipset list temp-country -name &> /dev/null
if [ $? -eq 0 ]
then
    ipset flush temp-country
    ipset destroy temp-country
fi

# add subnets to a temporary set
echo "Adding subnets to the $country_name IP set..."
sed \
-e '1 i\create temp-country hash:net family inet hashsize 1024 maxelem 65536' \
-e 's/\(.*\)/add temp-country \1/' \
$country_code-aggregated.zone | ipset restore

# swap or rename temporary set to country set
ipset list $country_name -name &> /dev/null
if [ $? -eq 0 ]
then
    ipset swap temp-country $country_name
    ipset flush temp-country
    ipset destroy temp-country
else
    ipset rename temp-country $country_name
fi

# if it does not exist, create the INPUT_country chain
iptables --new-chain INPUT_country &> /dev/null

# if it does not exist,
# insert the INPUT_country chain into the IN_public_deny chain
iptables --check IN_public_deny --jump INPUT_country &> /dev/null
if [ $? -ne 0 ]
then
    iptables --insert IN_public_deny --jump INPUT_country
fi

# if it does not exist, insert a rule for the country IPs set
iptables --check INPUT_country --match set --match-set $country_name src \
--jump $country_target &> /dev/null
if [ $? -ne 0 ]
then
    iptables --insert INPUT_country --match set --match-set $country_name src \
    --jump $country_target
fi

# if any INPUT_country rules jump to the ACCEPT target,
# the last rule should DROP
iptables -S INPUT_country | grep ACCEPT &> /dev/null
if [ $? -eq 0 ]
then
    iptables --check INPUT_country --jump DROP &> /dev/null
    if [ $? -ne 0 ]
    then
        iptables --append INPUT_country --jump DROP
    fi
else
    iptables --delete INPUT_country --jump DROP &> /dev/null
fi
