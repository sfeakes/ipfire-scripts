#!/bin/bash

####################################################################
# Create a hosts block list for use with unbound & dnsmasq         #
#                                                                  #
# Last updated: Jan 13 2021                                        #
# Version 1.5.0                                                    #
#                                                                  #
####################################################################

# Before we start or even set our own variables, check one setting on ipfire that's not 
# compatable with this script ENABLE_SAFE_SEARCH=on within dns settings.

if [ -f /var/ipfire/dns/settings ]; then
  if [ -f /usr/local/bin/readhash ]; then
    eval $(/usr/local/bin/readhash /var/ipfire/dns/settings)
    if [ "${ENABLE_SAFE_SEARCH}" = "on" ]; then
      >&2 echo "ERROR This script is not compatable with IPFire safe search, please turon off if you want to continue using this script"
      exit 1
    fi
  else
    # File exists, but we don't have ipfire's rehash.  so let's do quick n dirty test.
    if grep -q ENABLE_SAFE_SEARCH=on /var/ipfire/dns/settings; then
      >&2 echo "ERROR This script is not compatable with IPFire safe search, please turon off if you want to continue using this script"
      exit 1
    fi
  fi
fi

###########################################
# Let's really start now.

#DEFAULT_DNS="127.0.0.1"
DEFAULT_DNS="0.0.0.0"
INTERNAL_WHITELIST="localhost\|localhost.localdomain\|local"
VERSION="1.5"

# -l list sources
# -s sourcelist
# -w whitelist
# -b blacklist
# -r DNS Return (IP or NXDOMAIN)
# -u force unbound
# -d force dnsmasq
# -o outfile

# Need to check /var/ipfire/dns/settings and if that contains ENABLE_SAFE_SEARCH=on this script will not work. 
# Below command :-
# eval $(/usr/local/bin/readhash /var/ipfire/dns/settings)
# will allow use of :-
# if [ "${ENABLE_SAFE_SEARCH}" = "on" ]; then
####################################################################
# 
#

DEFAULT_BLOCK_HOST_URLS=( \
                 https://adaway.org/hosts.txt \
                 https://winhelp2002.mvps.org/hosts.txt \
                 https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
                 https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt
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

SELF=$(basename $0)

#
# Parse command line arguments.
#
parse_args() {
  while [[ $# > 0 ]] ; do
    case "$1" in
      -h | --help)
        list_usage
        exit
        ;;
      -l | --listsources)
        LIST_SOURCES=1
        ;;
      -f | --blocklist)
        BLOCKLIST_URL_FILE=${2}
        shift
        ;;
      -s | --sourcelist)
        SOURCES=${2}
        shift
        ;;
      -w | --whitelist)
        LOCAL_WHITELIST=${2}
        shift
        ;;		
      -b | --blacklist)
        LOCAL_BLACKLIST=${2}
        shift
        ;;
      -r | --dns_return)
        DNS_RETURN=${2}
        shift
        ;;
      -u | --force_unbind)
        USE_UNBIND=0
        ;;
	    -d | --force_dnsmasq)
        USE_UNBIND=1
        ;;
      -o | --outfile)
        OUTFILE=${2}
        shift
        ;;
      -v | --version)
        echo $0 v$VERSION
        exit 0
        ;;
    esac
    shift
  done
}

#
# Print to stdout or logger depending on if we are in an interactive shell
#
log () {
  # IF we are running interactivle just print, if not (ie from cron) then log to ipfire
  if [ -t 1 ]; then
    echo "$SELF: $*"
  else
    logger -t "$SELF" "$*"
  fi
}

#
# Derr
#
list_usage() {
  printf "$0 <parameters>\n  Parameters are the following, only use one of the formats, -p OR --parameter, do not use both\n"
  printf "  %-25s %s\n" "-h --help" "This message"
  printf "  %-25s %s\n" "-l --listsources" "list sources available with index number"
  printf "  %-25s %s\n" "-f --blocklist <filename>" "File with URL's of blocklist to retreive"
  printf "  %-25s %s\n" "-w --whitelist <filename>" "Use a white list file"
  printf "  %-25s %s\n" "-b --blacklist <filename>" "Use a blacklist file"
  printf "  %-25s %s\n" "-r --dns <ip or value>" "Set the dns return value"
  printf "  %-25s %s\n" "-u --force_unbind" "Force script to use unbind"
  printf "  %-25s %s\n" "-d --force_dnsmasq" "Force script to use dnsmasq"
  printf "  %-25s %s\n" "-o --outfile <filename>" "output to filename, do not restart any services"
  printf "  %-25s %s\n" "-s --sourcelist <list>" "list sources to retreive block from (must be comma seperated)"
  printf "  %-25s %s\n" "-v --version" "Print version of script and exit"
  printf "  %-25s %s\n" "" "use index number from -l value or URL"
  printf "\nExample:-  $0 -s 1,2,http://mylist.com/host.txt -r 0.0.0.0 \n"
  printf "\n *** See https://github.com/sfeakes/ipfire-scripts for more details ***\n"
}

#
# Print a list of supported URLs with an index number
#
list_sources() {
  cnt=1
  
  printf "\nAll URLs will be used unles the -s flag is passed\n\n"
  for url in "${BLOCK_HOST_URLS[@]}"; do
    printf "%2d %s\n" $cnt $url
	cnt=$((cnt+1))
  done
  echo ""
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
      last_domain=$domain
    fi
  done < $exp_reversefile

  cat $exp_tmpfile | awk -F "." '{for(i=NF; i > 1; i--) printf "%s.", $i; print $1}' > $TMP_HOSTS_FILE
}

#
# Download list of domains from URL and strip unwanted stuff.
#
pass_urls=0
fail_urls=0

get_list_from_url() {
  
  if [ ! -z $VERBOSE ]; then 
    ccount=$(cat $TMP_HOSTS_FILE | wc -l)
  fi
  
  # This awk is just for passing hosts files
  # bla | awk -v RS='\r|\n' '$1 ~ /^0.0.0.0|127.0.0.1/ {if ($2 != "localhost") printf "%s\n", tolower($2);}' 
  #
  # This awk is for passing the adblock output, not prefect the cleanup process captures the rest.  
  # Only lines with ||domain.name^ are used, all else thrown away
  # awk  -F'[\||\^| \t]+' -v RS='\r|\n' '{if ($0 ~ /^\|\|.*\^$/)  printf "%s\n",tolower($2) }' >> $TMP_HOSTS_FILE

  tcount=0
  # This awk tries to combine both above.
  curl -v --max-time 30 --connect-timeout 5 --silent "$1" --stderr - | awk  -F'[\\\\|\\\\^| \t]+' -v RS='\r|\n' '{if (($0 ~ /^\|\|.*\^$/ || $1 ~ /^0.0.0.0|127.0.0.1/) && $2 ~ /.*\.[a-z].*/)  printf "%s\n",tolower($2) }'  >> $TMP_HOSTS_FILE
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "FAILED to load hosts from URL '$1'"
    fail_urls=$((fail_urls+1))
  else
    pass_urls=$((pass_urls+1))
    tcount=$(cat $TMP_HOSTS_FILE | wc -l)
    added=$(expr $tcount - $ccount)
    if [ $added -le 0 ]; then
      # Good curl but no domain names, let's try simple formatted style list.
      #log "Retreived 0 domain names from $1, trying alternate format"
      curl -v --max-time 30 --connect-timeout 5 --silent "$1" --stderr - | awk '{ if ($1 ~ /^[a-zA-Z0-9-].[a-zA-Z0-9\.-]/ ) printf "%s\n",tolower($1) }'  >> $TMP_HOSTS_FILE
      tcount=$(cat $TMP_HOSTS_FILE | wc -l)
    fi
  fi
  
  log "Retreived $(expr $tcount - $ccount) domain names from $1"
  # If the above fails, look at plane domain list using regexp like '/^[a-zA-Z0-9].[a-zA-Z0-9.]/'
  #
  #if [ ! -z $VERBOSE ]; then 
  #  #tcount=$(cat $TMP_HOSTS_FILE | wc -l)
  #  echo "Retreived $(expr $tcount - $ccount) domain names from $1"
  #fi
}

read_sources() {
  if [ ! -z $BLOCKLIST_URL_FILE ]; then
    readarray -t BLOCK_HOST_URLS < <(cat $BLOCKLIST_URL_FILE | grep -i "^http")
  else
    BLOCK_HOST_URLS=(${DEFAULT_BLOCK_HOST_URLS[@]})
  fi
}




####################################################################
# 
# Main
#
####################################################################


parse_args "$@"

# Be verbose if running in an interactive shell
if [[ -z $VERBOSE && -t 1 ]]; then
  VERBOSE=1
fi

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

if [ -z $DNS_RETURN ]; then
  DNS_RETURN=$DEFAULT_DNS
fi

if [ ! -z $OUTFILE ]; then
  FINAL_HOSTS=$OUTFILE
else
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

if [ -f "$TMP_HOSTS_FILE" ]; then
  rm -f $TMP_HOSTS_FILE
fi

# Load the URL's we are going to use
read_sources

if [ ! -z $LIST_SOURCES ]; then
  list_sources
  exit 0
fi

if [ -f "$LOCAL_BLACKLIST" ]; then
  # Below is for blacklist in host file format
  #cat $LOCAL_BLACKLIST | awk '$1 ~ /^[0.0.0.0|127.0.0.1]/ {printf "%s\n", tolower($2)}' > $TMP_HOSTS_FILE
  grep -P '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$' $LOCAL_BLACKLIST >  $TMP_HOSTS_FILE
  count=$(cat $TMP_HOSTS_FILE | wc -l)
  log "Retreived $count domain names from local blacklist file"
else
  touch $TMP_HOSTS_FILE
fi


cnt=1

if [ ! -z $SOURCES ]; then
  SOURCES=",$SOURCES,"
fi

# Build the host file from the URL's
for url in "${BLOCK_HOST_URLS[@]}"; do
  if [ -z $SOURCES ] || [[ $SOURCES =~ ",$cnt," ]]; then
    get_list_from_url $url
  fi
  cnt=$((cnt+1))
done

# Check if any URLs exist in the source list
shopt -s nocasematch
IFS=',' read -ra ADDR <<< "$SOURCES"
for i in "${ADDR[@]}"; do
  if [[ $i =~ ^http ]]; then
    get_list_from_url $i
  fi
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

#if [ ! -z $VERBOSE ]; then 
  log "Cleaning & Sorting list of `cat $TMP_HOSTS_FILE | wc -l` entries"
#fi

#sed 's/^\.//;s/\.$//' $TMP_HOSTS_FILE | sort > $TMP_HOSTS_FILE.out
#mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE

# Basic check for valid domain name.  Check is group '.' group.  
# Group can be a-Z and 0-9, 61 characters in total. - is allowed, but only in the middle of a group.
# Also added _ to allowed character.  While this isn't valid, some domains & browsers seem to use it.
# this removes any bad domain names, which is why I remove any leading or trailing periods before this 
sed 's/^\.//;s/\.$//' $TMP_HOSTS_FILE | grep -P '^(?:[a-z0-9](?:[a-z0-9-_]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-_]{0,61}[a-z0-9]$' > $TMP_HOSTS_FILE.out
mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE

if [[ ! -z $LOCAL_WHITELIST && -f $LOCAL_WHITELIST ]]; then
  cat $TMP_HOSTS_FILE | grep -v -x -f $LOCAL_WHITELIST > $TMP_HOSTS_FILE.out
  if [ ! -z $VERBOSE ]; then 
    bcount=$(cat $TMP_HOSTS_FILE | wc -l)
    acount=$(cat $TMP_HOSTS_FILE.out | wc -l)
    log "Removed $(expr $bcount - $acount) domain names due to whitelist"
  fi
  mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE
fi

grep -v $INTERNAL_WHITELIST $TMP_HOSTS_FILE | sort | uniq > $TMP_HOSTS_FILE.out
mv -f $TMP_HOSTS_FILE.out $TMP_HOSTS_FILE

finalcount=$(wc -l < $TMP_HOSTS_FILE)

echo "####################################################################" >  $FINAL_HOSTS
echo "# Block malicious sites at DNS level.                              #" >> $FINAL_HOSTS
echo "# This file should not be manually edited                          #" >> $FINAL_HOSTS
echo "# Created by $(basename $0) v$VERSION                                 #" >> $FINAL_HOSTS
echo "# Last updated: `date`                       #" >> $FINAL_HOSTS
echo "####################################################################" >>  $FINAL_HOSTS
echo "" >> $FINAL_HOSTS

if [ $USE_UNBIND -eq 0 ]; then
  echo "server:" >> $FINAL_HOSTS

  if [ "$DNS_RETURN" == "refuse" -o "$DNS_RETURN" == "static" -o "$DNS_RETURN" == "always_refuse" -o "$DNS_RETURN" == "always_nxdomain" ]; then
    experemental_nxdomain
    finalcount=$(wc -l < $TMP_HOSTS_FILE)
    if [ ! -z $VERBOSE ]; then echo Writing list of $finalcount entries to unbound nxdomain configuration; fi
    awk -v rtn=$DNS_RETURN '{printf "local-zone: \"%s\" %s\n",$1,rtn}' < $TMP_HOSTS_FILE >> $FINAL_HOSTS
  else
    if [ ! -z $VERBOSE ]; then echo Writing list of $finalcount entries to unbound configuration; fi
    awk -v ip=$DNS_RETURN '{printf "local-data: \"%s A %s\"\n",$1,ip}' < $TMP_HOSTS_FILE >> $FINAL_HOSTS
  fi
else
  if [ ! -z $VERBOSE ]; then echo Writing list of $finalcount entries to dnsmasq hosts format; fi
  if [[ ! $DNS_RETURN =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log "IP address $DNS_RETURN is not valid for dnsmasq, using $DEFAULT_DNS"
    DNS_RETURN=$DEFAULT_DNS
  fi
  awk -v ip=$DNS_RETURN '{printf "%s %s\n",ip,$1}' < $TMP_HOSTS_FILE >> $FINAL_HOSTS
fi

# Change permissions on final file
chmod 644 $FINAL_HOSTS

# Cleanup
rm -f $TMP_HOSTS_FILE

if [ ! -z $OUTFILE ]; then
  log "Written $finalcount entries to $FINAL_HOSTS"
  exit
fi

# Restart local DNS server for changes to take effect
if [[ ! -z $SYSTEMD_SERVICE && -f $SYSTEMD_SERVICE ]]; then
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

