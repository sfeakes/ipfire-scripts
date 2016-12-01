# ipfire-scripts #

## dns_blocker.sh ##

Will download hosts that are labeled as malicious from multiple sources and create a file that will cause unbound or dnsmasq to block them via DNS queries. 

To install, ssh to your ipfire machine and use the following commands.
- cd ~
- mkdir -p bin
- cd bin
- wget https://raw.githubusercontent.com/sfeakes/ipfire-scripts/master/dns_blocklist.sh
- chmod 755 dns_blocklist.sh

Then simply run the script every time you want to update the blocklist. (use fcrontab to run it a regular intervals with cron)

Below are a list of the sources that can be configured in the script.

| URL                                                                              | Details                                                 | License |
| -------                                                                          | -------                                                 | ------- |
|[Adaway list](https://adaway.org/hosts.txt)                                       | Infrequent updates, approx. 400 entries                 | CC Attribution 3.0 |
|[Malware domain list] (http://www.malwaredomainlist.com/hostslist/hosts.txt)      | Daily updates                                           | non-commercial community project |
|[MVPS Hosts](http://winhelp2002.mvps.org/hosts.htm)                               | Infrequent updates, approx. 15.000 entries              | CC Attribution-NonCommercial-ShareAlike 4.0 |
|[Peter Lowe’s Ad server list](http://pgl.yoyo.org/adservers/)                     | Weekly updates, approx. 2.500 entries                   | ? |
|[StevenBlack - hosts](https://github.com/StevenBlack/hosts/)                      |                                                         | ? |
|[Dan Pollock’s hosts file](http://someonewhocares.org/hosts/)                     | Weekly updates, approx. 12.000 entries                  | non-commercial |
|[CAMELEON](http://sysctl.org/cameleon/)                                           | Weekly updates, approx. 21.000 entries                  | ? |
|[hpHosts‎](http://www.hosts-file.net/)                                             | Daily updates, very large and error prone               | *Read [Terms of Use](http://www.hosts-file.net/)* |
|[Hostfile project](http://hostsfile.org/hosts.html)                               | Weekls updates                                          | LGPL as GPLv2 |
|[The Hosts File Project](http://hostsfile.mine.nu)                                | Infrequent updates                                      | LGPL |
|[notracking - hosts-blocklists](https://github.com/notracking/hosts-blocklists)   | Daily updates, (Includes most of above and others)      | ? |
|[Airelle's host file](http://rlwpx.free.fr/WPFF/hosts.htm)                        | NOT SUPPORTED YET                                       | CC Attribution 3.0 |
|[Shalla's Blacklists ](http://www.shallalist.de/)                                 | NOT SUPPORTED YET                                       | ? |

