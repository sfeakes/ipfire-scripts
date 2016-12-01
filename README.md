# ipfire-scripts #

## dns_blocker.sh ##

Will download hosts that are labeled as malicious from multiple sources and create a file that will cause unbound or dnsmasq to block them via DNS queries.
The file will have duplicates and most (if not all) bad entries removed.  If you use the expermental nxdomain option, will also have duplicate sub domains removed.  

To install, ssh to your ipfire machine and use the following commands.
    cd ~
    mkdir -p bin
    cd bin
    wget https://raw.githubusercontent.com/sfeakes/ipfire-scripts/master/dns_blocklist.sh
    chmod 755 dns_blocklist.sh

Then simply run the script every time you want to update the blocklist. (use fcrontab to run it a regular intervals with cron)

### If you are using dnsmasq and not unbount, there is one further step ###
(dnsmasq is default on IPFire 2.19 - Core Update 105 and below)  
(unbound is default on IPFire 2.19 - Core Update 106 and above)

- create a file /etc/sysconfig/dnsmasq with following the contents
- CUSTOM_ARGS="--addn-hosts=/var/ipfire/dhcp/blocked.hosts"

### unbound ###

By default this script will tell the dns server to return a IP address for each entry, this means the source lists have to be very accurate and no wildcards can be used. For example, if your blocklist contains :-
    junk1.doubleclick.net
    junk2.doubleclick.net
    doubleclick.net
    ad.junk1.doubleclick.net


Only those exact domains will be rejected. This will allow all subdomains, ie `ad2.junk1.doubleclick.net & junk3.doubleclick.net` to be accepted.  
If you look at some of the lists from the sources, you will see hundreds of sub domains that all need to be blocked, and constantly get updated as new ones come out.

With the “expermental nxdomain” option set, the script will sort all those domains down to the minimum, and block everything under that. In the example above it will simple use `doubleclick.net`, and block that and every domain under it. `eg *.doubleclick.net`

To turn this option on, set the variable UNBIND_RETURN to either `refuse`, `static`, `always_refuse` or `always_nxdomain`. Description of these can be found in the "local-zone": section of the following URL.
https://www.unbound.net/documentation/unbound.conf.html


### Below are a list of the sources that can be configured (turned on or off) in the script ###

| URL                                                                              | Details                                              | License |
| -------                                                                          | -------                                              | ------- |
|[Adaway list](https://adaway.org/hosts.txt)                                       | Infrequent updates, approx. 500 entries              | CC Attribution 3.0 |
|[Malware domain list] (http://www.malwaredomainlist.com/hostslist/hosts.txt)      | Daily updates, aprox 1,300                           | non-commercial community project |
|[MVPS Hosts](http://winhelp2002.mvps.org/hosts.htm)                               | Infrequent updates, approx. 500 entries              | CC Attribution-NonCommercial-ShareAlike 4.0 |
|[Peter Lowe’s Ad server list](http://pgl.yoyo.org/adservers/)                     | Weekly updates, approx. 2,500 entries                | ? |
|[StevenBlack - hosts](https://github.com/StevenBlack/hosts/)                      | Weekly updates, approx. 34,000 entries               | ? |
|[Dan Pollock’s hosts file](http://someonewhocares.org/hosts/)                     | Weekly updates, approx. 12.000 entries               | non-commercial |
|[CAMELEON](http://sysctl.org/cameleon/)                                           | Weekly updates, approx. 21.000 entries               | ? |
|[hpHosts‎](http://www.hosts-file.net/)                                             | Daily updates,  approx. 500,000 and error prone      | *Read [Terms of Use](http://www.hosts-file.net/)* |
|[Hostfile project](http://hostsfile.org/hosts.html)                               | Weekls updates, approx. 25,000 entries               | LGPL as GPLv2 |
|[The Hosts File Project](http://hostsfile.mine.nu)                                | Infrequent updates, approx 95,000 entries            | LGPL |
|[notracking - hosts-blocklists](https://github.com/notracking/hosts-blocklists)   | Daily updates, approx 26,000 (Includes some of above)| ? |
|[Airelle's host file](http://rlwpx.free.fr/WPFF/hosts.htm)                        | NOT SUPPORTED YET                                    | CC Attribution 3.0 |
|[Shalla's Blacklists ](http://www.shallalist.de/)                                 | NOT SUPPORTED YET                                    | ? |

