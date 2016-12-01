#!/bin/bash

####################################################################
# Create a hosts block list for use with unbound & dnsmasq         #
#                                                                  #
# Last updated: Dec 01 2016                                        #
# Version 1.2.6                                                    #
#                                                                  #
####################################################################

# Set your local whitelist and blacklist file.
# these should just contain domain names, one per line, nothing else.
LOCAL_BLACKLIST="./blacklist"
LOCAL_WHITELIST="./whitelist"

####################################################################
# Advanced configuration
#
# If you want unbound to return an IP address put it below,
# 127.0.0.1 will be used if commented out
#UNBIND_RETURN="0.0.0.0"
#
# EXPEREMENTAL make sure you read notes on main github page
# if you want unbind to reject DNS request, rather than return an ip
# use one of the qualifyers below
#       refuse static always_refuse always_nxdomain
#UNBIND_RETURN="refuse"
#
# Script will work out if you are using unbind or dnsmasq, you can hard code it
# if you want
# 0 = use unbind, 1 = use dnsmasq, commented out = script to caculate
#USE_UNBIND=0
#
# If you don't want to use the default host location, uncomment below
#FINAL_HOSTS="./blocklist.conf"

# Uncomment / comment any sources you want to use to build your block list.
#
BLOCK_HOST_URLS=( \
                 https://adaway.org/hosts.txt \
                 http://www.malwaredomainlist.com/hostslist/hosts.txt \
                 http://winhelp2002.mvps.org/hosts.txt \
                 "http://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" \
                 https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
#                 http://someonewhocares.org/hosts/ \
#                 http://sysctl.org/cameleon/hosts \
#                 http://hosts-file.net/ad_servers.txt \
#                 http://hosts-file.net/download/hosts.txt \
#                 http://hostsfile.org/Downloads/hosts.txt \
#                 http://hostsfile.mine.nu/Hosts.txt \
#                 https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt \
                )



####################################################################
# There should be no need to edit beyond this point.
#
#

TMP_HOSTS_FILE="/var/tmp/hosts.block"
UNBOUND_FINAL_HOSTS="/etc/unbound/local.d/blocklist.conf"
DNSMASQ_FINAL_HOSTS="/var/ipfire/dhcp/blocked.hosts"

UNBOUND_SYSTEMD_SERVICE="/etc/init.d/unbound"
DNSMASQ_SYSTEMD_SERVICE="/etc/init.d/dnsmasq"

log () {
  # IF we are running interactivle just print, if not (ie from cron) then log to ipfire
  if [ -t 1 ]; then
    echo "$0: $1"
  else
    logger -t ipfire "$0: $1"
  fi
}

# I'm sure there is a cleaner way to do this, but this is what I've come up with so far.
# create a TLD list in reverse, ie com.google.ad
# sort that list (linux sort -f is used, works well on ipfire but probably iffy on other distributions)
# run through TLD list and pick the shortest one.  ie if both com.google.ad & com.google.ad.bla exist, 
# only use com.google.ad
# reverse the TLD list again
# use this reduced list and reject DNS requests on it
experemental_nxdomain () {
  exp_tmpfile="$TMP_HOSTS_FILE.experemental"
  exp_reversefile="$TMP_HOSTS_FILE.reverse"

  # sort -f is to ingore case, but it works at soring domain names. a.b.c, a.b.c.1, a.b.c1 (without -f a.b.c, a.b.c1, a.b.c.1)
  cat $TMP_HOSTS_FILE | awk -F "." '{for(i=NF; i > 1; i--) printf "%s.", $i; print $1}' | uniq | sort -f > $exp_reversefile

  if [ -f $exp_tmpfile ]; then
    rm -rf $exp_tmpfile
  fi

  while read domain; do
    if [ -z $last_domain ]; then
      last_domain=$domain
      continue
    fi

    if [[ ! $domain =~ $last_domain\..* ]]; then
      echo $last_domain >> $exp_tmpfile
#      echo "ADD    $last_domain"
      last_domain=$domain
#    else
#      echo "IGNORE $domain exists in $last_domain"
    fi
  done < $exp_reversefile

  cat $exp_tmpfile | awk -F "." '{for(i=NF; i > 1; i--) printf "%s.", $i; print $1}' > $TMP_HOSTS_FILE
}

if [ -z $USE_UNBIND ]; then
  if [ -f "$UNBOUND_SYSTEMD_SERVICE" ]; then
    USE_UNBIND=0
  elif [ -f "$DNSMASQ_SYSTEMD_SERVICE" ]; then
    USE_UNBIND=1
  else
    log "ERROR Can't determin if system is using unbund or dnsmasq"
    exit 1
  fi
fi

if [ -z $UNBIND_RETURN ]; then
  UNBIND_RETURN="127.0.0.1"
fi

if [ -z $FINAL_HOSTS ]; then
  if [ $USE_UNBIND -eq 0 ]; then
    FINAL_HOSTS=$UNBOUND_FINAL_HOSTS
  else
    FINAL_HOSTS=$DNSMASQ_FINAL_HOSTS
  fi
fi

if [ -z $SYSTEMD_SERVICE ]; then
  if [ $USE_UNBIND -eq 0 ]; then
    SYSTEMD_SERVICE=$UNBOUND_SYSTEMD_SERVICE
  else
    SYSTEMD_SERVICE=$DNSMASQ_SYSTEMD_SERVICE
  fi
fi


pass_urls=0
fail_urls=0

get_list_from_url() {
  curl -v --max-time 8 --silent "$1" --stderr - | awk -v RS='\r|\n' '$1 ~ /^[0.0.0.0|127.0.0.1]/ {if ($2 != "localhost") printf "%s\n", tolower($2);}' >> $TMP_HOSTS_FILE

  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "FAILED to load hosts from URL '$1'"
    fail_urls=$((fail_urls+1))
  else
    pass_urls=$((pass_urls+1))
  fi
}

if [ -f "$TMP_HOSTS_FILE" ]; then
  rm -f $TMP_HOSTS_FILE
fi

if [ -f "$LOCAL_BLACKLIST" ]; then
  # Below is for blacklist in host file format
  #cat $LOCAL_BLACKLIST | awk '$1 ~ /^[0.0.0.0|127.0.0.1]/ {printf "%s\n", tolower($2)}' > $TMP_HOSTS_FILE
  grep -P '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$' $LOCAL_BLACKLIST >  $TMP_HOSTS_FILE
else
  touch $TMP_HOSTS_FILE
fi

# Build the host file from the URL's
for url in "${BLOCK_HOST_URLS[@]}"; do
  get_list_from_url $url
done

# Check how many URL's failed, if more than 50% don't update any further
if [ `expr $fail_urls \* 2` -gt $pass_urls ]; then
  log "Too many failed URL's, not updating block list"
  exit
fi

# Clean, sort & filter the host file
# remove any leading or trailing .
# sort the list
# remove any lines matching the whitelist file
# make sure all entries are uniq

sed 's/^\.//;s/\.$//' $TMP_HOSTS_FILE | sort > $TMP_HOSTS_FILE.out
mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE

if [ -f $LOCAL_WHITELIST ]; then
  cat $TMP_HOSTS_FILE | grep -v -x -f $LOCAL_WHITELIST > $TMP_HOSTS_FILE.out
  mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE
fi

sort $TMP_HOSTS_FILE | uniq > $TMP_HOSTS_FILE.out
mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE

finalcount=$(wc -l < $TMP_HOSTS_FILE)

echo "####################################################################" >  $FINAL_HOSTS
echo "# Block malicious sites at DNS level.                              #" >> $FINAL_HOSTS
echo "# This file should not be manually edited                          #" >> $FINAL_HOSTS
echo "# Last updated: `date`                       #" >> $FINAL_HOSTS
echo "####################################################################" >>  $FINAL_HOSTS
echo "" >> $FINAL_HOSTS

if [ $USE_UNBIND -eq 0 ]; then
  echo "server:" >> $FINAL_HOSTS

  if [ "$UNBIND_RETURN" == "refuse" -o "$UNBIND_RETURN" == "static" -o "$UNBIND_RETURN" == "always_refuse" -o "$UNBIND_RETURN" == "always_nxdomain" ]; then
    experemental_nxdomain
    finalcount=$(wc -l < $TMP_HOSTS_FILE)
    awk -v rtn=$UNBIND_RETURN '{printf "local-zone: \"%s\" %s\n",$1,rtn}' < $TMP_HOSTS_FILE >> $FINAL_HOSTS
  else
    awk -v ip=$UNBIND_RETURN '{printf "local-data: \"%s A %s\"\n",$1,ip}' < $TMP_HOSTS_FILE >> $FINAL_HOSTS
  fi
else
  awk '{printf "127.0.0.1 %s\n",$1}' < $TMP_HOSTS_FILE >> $FINAL_HOSTS
fi

# Change permissions on final file
chmod 644 $FINAL_HOSTS

# Cleanup
rm -f $TMP_HOSTS_FILE

# Restart local DNS server for changes to take effect
if [[ ! -z $SYSTEMD_SERVICE && -f $SYSTEMD_SERVICE ]]; then
  # Seems to be a bug in upstart initd, restart will fail if there are a lot of hosts
  # so run a stop pause start instead.
  $SYSTEMD_SERVICE restart

  # Check unbound came up correctly
  status=$($SYSTEMD_SERVICE status)

  if [[ $status =~ .*is\ not\ running.* ]]; then
    mv $FINAL_HOSTS $FINAL_HOSTS.bad
    $SYSTEMD_SERVICE restart
    log "ERROR: $SYSTEMD_SERVICE failed to start with blocked hosts file, removed blocked hosts file and restarted."
  else
    # Write to log file
    log "Blocked Hosts Update, $finalcount hosts blocked"
  fi
else
  log "Blocked Hosts Update, $finalcount hosts written to $FINAL_HOSTS"
fi

