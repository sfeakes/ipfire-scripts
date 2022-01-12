# ipfire-scripts #

## dns_blocker.sh ##

Designed to block domains at your ipFire firewall. ie (Add blocker of equivelent of what PiHole does)
The script will download list of hosts / domains that are labeled as malicious from multiple sources and create a file that will cause unbound or dnsmasq to block them via DNS queries.
Usually these files are very large, since they contain many duplicates and multiple levels of domain names, this script is also designed to remove all of those, (more info in nxdomain section)
For retreiving sources, Host file format and adblock format is supported.
For writing to DNS configurations, unbound, dnsmasq are supported.
If you want to write a local hosts file, you will need to modify the output with you local configuration.

To install, ssh to your ipfire machine and use the following commands.
```
cd ~
mkdir -p bin
cd bin
curl -O https://raw.githubusercontent.com/sfeakes/ipfire-scripts/master/dns_blocklist.sh
chmod 755 dns_blocklist.sh
```
To test the script's output run the below command, it will not make any system modifications with -o passed.
```
dns_blocklist.sh -o /tmp/dnsblock.out

you should see something like the below:-
Retreived 23 domain names from local blacklist file
Retreived 7563 domain names from https://adaway.org/hosts.txt
Retreived 8730 domain names from https://winhelp2002.mvps.org/hosts.txt
Retreived 96293 domain names from https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
Retreived 75498 domain names from https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt
Retreived 16194 domain names from https://easylist.to/easylist/easylist.txt
Retreived 102 domain names from https://easylist.to/easylist/fanboy-annoyance.txt
Cleaning & Sorting list of 204380 entries
Writing list of 158000 entries to unbound configuration
Written 158000 entries to /tmp/dnsblock.out
```



Then simply run the script every time you want to update the blocklist. (use fcrontab to run it a regular intervals with cron)
below is an example fcrontab entry that runs at midnight every day.
```
0 * * * *  /root/dns_blocklist.sh
```

The github repo also contains blacklist, whitelist & blocklist.sources example files you can use and modify.

## If you are using dnsmasq and not unbound, there is one further step ###
(dnsmasq is default on IPFire 2.19 - Core Update 105 and below)  
(unbound is default on IPFire 2.19 - Core Update 106 and above)

- create a file `/etc/sysconfig/dnsmasq` with following the contents
- `CUSTOM_ARGS="--addn-hosts=/var/ipfire/dhcp/blocked.hosts"`

## Command line parameters ##
```
./dns_blocklist.sh <parameters>
  Parameters are the following, only use one of the formats, -p OR --parameter, do not use both
  -h --help                 This message
  -l --listsources          list sources available with index number
  -f --blocklist <filename> File with URL's of blocklist to retreive
  -w --whitelist <filename> Use a white list file
  -b --blacklist <filename> Use a blacklist file
  -r --dns <ip or value>    Set the dns return value
  -u --force_unbind         Force script to use unbind
  -d --force_dnsmasq        Force script to use dnsmasq
  -o --outfile <filename>   output to filename, do not restart any services
  -s --sourcelist <list>    list sources to retreive block from (must be comma seperated)
  -v --version              Print version of script and exit
                            use index number from -l value or URL


Example:-  ./dns_blocklist.sh -s 1,2,http://mylist.com/host.txt -r 0.0.0.0
```
## Custom blocklists  ##

dns_blocklist has some default blocklists it uses that are kept up to date and very accurate, details at the bottom of this page.  You can create you own list by creating a file with the list of URL's, and using the -f command line paramater.

`dns_blocklist.sh -f blockurls.source`

contents of file `blockurls.source`
```
https://adaway.org/hosts.txt
https://winhelp2002.mvps.org/hosts.txt
#https://raw.githubusercontent.com/matomo-org/referrer-spam-blacklist/master/spammers.txt
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt
https://easylist.to/easylist/easylist.txt
https://easylist.to/easylist/fanboy-annoyance.txt
```


## Custom blacklist & whitelist  ##
Example
```
dns_blocklist.sh –b ~/user/blacklist.hosts –w ~/user/whitelist.hosts
```

Change the above to point to your custom files. The files should contain domain names only. blacklist will be added to the DNS block list, whitelist will be used to remove any entries that match from the source blocklists that are downloaded.
```
# example blacklist /var/ipfire/dhcp/blacklist
activate.adobe.com
www.trovi.com
cdn.wanderburst.com
www.wanderburst.com
d13.zedo.com
d3.zedo.com
wanderburst.akamaihd.net
wanderburst-a.akamaihd.net
```

## IP that the DNS server returns  ##
Example
```
dns_blocklist.sh –r 127.0.0.1
dns_blocklist.sh –r refuse
```

Change to any IP you like the DNS server to return, the default is 0.0.0.0 for both dnsmasq & unbound.
Or for unbound, you can use `refuse`, `static`, `always_refuse`, `always_nxdomain` or any other tag you want to define. Read the below for details
https://unbound.docs.nlnetlabs.nl/en/latest/topics/filtering/tags-views.html

## unbound nxdomain  ##

By default this script will tell the dns server to return a IP address for each entry, this means the source lists have to be very accurate and no wildcards can be used. For example, if your blocklist contains :-
```
 junk1.doubleclick.net
 junk2.doubleclick.net
 doubleclick.net
 ad.junk1.doubleclick.net
 adjunk.google.com
```

Only those exact domains will be rejected. This will allow all subdomains, ie `ad2.junk1.doubleclick.net & junk3.doubleclick.net` to be accepted.  
If you look at some of the lists from the sources, you will see hundreds of sub domains that all need to be blocked, and constantly get updated as new ones come out.

With the nxdomain option set the script will sort all those domains down to the minimum, and block everything under that. In the example above it will simple use `doubleclick.net`, and block that and every domain under it. `eg *.doubleclick.net`

To turn this option on, set the command line parameter -r or --dns to either `refuse`, `static`, `always_refuse` or `always_nxdomain`. Description of these can be found in the "local-zone": section of the following URL.
https://unbound.docs.nlnetlabs.nl/en/latest/topics/filtering/tags-views.html

Using the above list, running the script in normal mode will create a file like
```
local-data: "junk1.doubleclick.net A 127.0.0.1"
local-data: "junk1.doubleclick.net A 127.0.0.1"
local-data: "junk2.doubleclick.net A 127.0.0.1"
local-data: "doubleclick.net A 127.0.0.1"
local-data: "ad.junk1.doubleclick.net A 127.0.0.1"
local-data: "adjunk.google.com A 127.0.0.1"
```

Running the scrtipt in expermental nxdomain would create the following
```
local-zone: "doubleclick.net" reject
local-zone: "adjunk.google.com" reject
```

## Enable / Disable known sources and Add new sources for the blocklist generation  ##
Example
```
dns_blocklist.sh -l
dns_blocklist.sh -s 1,2,5
dns_blocklist.sh -s 1,2,http://mylist.com/host.txt 
dns_blocklist.sh -s 1,"http://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
```

List default sources with the –l parameter. This will list sources with an ID next to each, use this ID with the -s parameter.  
Enable sources with –s Can be a list of numbers and urls, that are comma separated and contain no spaces.  If a number is used, the corresponding known source will be used to download sources from, if a url is used, the script will try to download content from that url. If you need to pass query parameters, then quots muse be used. 

### Below are a list of the sources that can be configured (turned on or off) with -s parameter ###

| URL                                                                              | Details                                              | License |
| -------                                                                          | -------                                              | ------- |
|[Adaway list](https://adaway.org/hosts.txt)                                       | Infrequent but accurate updates, approx. 8k entries              | CC Attribution 3.0 |
|[MVPS Hosts](http://winhelp2002.mvps.org/hosts.htm)                               | Infrequent but accurate updates, approx. 9k entries              | CC Attribution-NonCommercial-ShareAlike 4.0 |
|[StevenBlack - hosts](https://github.com/StevenBlack/hosts/)                      | Weekly updates, approx. 100k entries, File that PiHole uses               | ? |
|[notracking - hosts-blocklists](https://github.com/notracking/hosts-blocklists)   | Daily updates, approx 80k (Includes some of above)| ? |

Below are ones that can be used, and at one time were used, but the above seems to captrure them.
| URL                                                                              | Details                                              | License |
| -------                                                                          | -------                                              | ------- |
|[Malware domain list](http://www.malwaredomainlist.com/hostslist/hosts.txt)      | Daily updates, aprox 1,300                           | non-commercial community project |
|[MVPS Hosts](http://winhelp2002.mvps.org/hosts.htm)                               | Infrequent updates, approx. 500 entries              | CC Attribution-NonCommercial-ShareAlike 4.0 |
|[Peter Lowe’s Ad server list](http://pgl.yoyo.org/adservers/)                     | Weekly updates, approx. 2,500 entries                | ? |
|[StevenBlack - hosts](https://github.com/StevenBlack/hosts/)                      | Weekly updates, approx. 34,000 entries               | ? |
|[Dan Pollock’s hosts file](http://someonewhocares.org/hosts/)                     | Weekly updates, approx. 12.000 entries               | non-commercial |
|[CAMELEON](http://sysctl.org/cameleon/)                                           | Weekly updates, approx. 21.000 entries               | ? |
|[hpHosts](http://www.hosts-file.net/)                                             | Daily updates,  approx. 500,000 and error prone      | *Read [Terms of Use](http://www.hosts-file.net/)* |
|[Hostfile project](http://hostsfile.org/hosts.html)                               | Weekls updates, approx. 25,000 entries               | LGPL as GPLv2 |
|[The Hosts File Project](http://hostsfile.mine.nu)                                | Infrequent updates, approx 95,000 entries            | LGPL |
|[notracking - hosts-blocklists](https://github.com/notracking/hosts-blocklists)   | Daily updates, approx 26,000 (Includes some of above)| ? |
|[EasyList ](https://easylist.to/easylist/easylist.txt)                            | *Adblock* list, approx 500 entries                   | ? |
|[Fanboy's Annoyance List ](https://easylist.to/easylist/fanboy-annoyance.txt)     | *Adblock* list, approx 20 entries                    | ? |
|[Airelle's host file](http://rlwpx.free.fr/WPFF/hosts.htm)                        | NOT SUPPORTED YET                                    | CC Attribution 3.0 |
|[Shalla's Blacklists ](http://www.shallalist.de/)                                 | NOT SUPPORTED YET                                    | ? |

Sources markes as *Adblock*, are not the best source format as they are specific to web browser blocking and not domain level blocking. But this script will pass the format and extract any TLD's that are listed. 


# Other scripts #


## create_ios_openvpn.sh ##

Create a client vpn file for use on an IOS / Android device with OpenVPN Connect app
