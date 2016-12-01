#!/bin/bash

EXTERNAL="my.domain.name"

ROOT="/var/ipfire"
FILE="$ROOT/ovpn/certs/$1.p12"
CFG="$ROOT/ovpn/settings"

if [ -f "$FILE" ];
then

#echo "tls-client" > $1.ovpn
echo "client" >> $1.ovpn
echo "dev tun" >> $1.ovpn
echo "proto udp" >> $1.ovpn
echo "remote $EXTERNAL `cat $CFG | grep DDEST_PORT= | cut -d= -f2`" >> $1.ovpn
echo "resolv-retry infinite" >> $1.ovpn
echo "nobind" >> $1.ovpn
echo "persist-key" >> $1.ovpn
echo "tun-mtu `cat $CFG | grep DMTU= | cut -d= -f2`" >> $1.ovpn
echo "cipher `cat $CFG | grep DCIPHER= | cut -d= -f2`" >> $1.ovpn
if [ "`cat $CFG | grep DCOMPLZO=on`" != "" ]; then
  echo "comp-lzo" >> $1.ovpn
fi
echo "verb 3" >> $1.ovpn
echo "ns-cert-type server" >> $1.ovpn
echo "key-direction 1" >> $1.ovpn

echo "<ca>" >> $1.ovpn
openssl pkcs12 -in $FILE -cacerts -nokeys -passin pass: >> $1.ovpn
echo "</ca>" >> $1.ovpn
echo "<cert>" >> $1.ovpn
openssl pkcs12 -in $FILE -clcerts -nokeys -passin pass: >> $1.ovpn
echo "</cert>" >> $1.ovpn
echo "<key>" >> $1.ovpn
openssl pkcs12 -in $FILE -nocerts -nodes -passin pass: >> $1.ovpn
echo "</key>" >> $1.ovpn

else
   echo "File $FILE does not exist" >&2
   echo "Syntax: $0 CertName"
   echo "CertName = certificate p12 file name, one of the following :-"
   echo `ls $ROOT/ovpn/certs/*.p12 | sed "s/.*\//--> /" | sed "s/\..*/ <--/"`
fi
