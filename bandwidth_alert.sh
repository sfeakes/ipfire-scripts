#!/bin/bash
# Run once a day to monitor bandwidth quota and email alert if trending over
#
# Monthly allowance in Gibibyte or GiB (NOT GIGABYTE GB) ie  1 TiB = 1024 GiB
month_GiB_allowance=1024

# Who do we send alerts to 
emailto="me@my.com,me@myother.com"
emailfrom="\"Bandwidth monitor\" <Bandwidth@my.ipfiredomain.com>"

GiBtoMiB=1024

# current day
day=$(date +%d)

# Days in current month
daysinmonth=$(date -d "`date +%m`/1/2016 + 1 month - 1 day" +%d)

# Caculate the allowance for the current day
allowance=$(echo "($month_GiB_allowance * $GiBtoMiB) / $daysinmonth * $day" | bc -l)

state=$(/usr/bin/vnstat --dumpdb -i red0 | awk -v "max=$allowance" --field-separator ";" '{if($1=="m"&&$2=="0"&&$8=="1"){if( ($4+$5) > max) print 1; else print 0;}}')

# If we are under, just exit
if [ $state -eq 0 ]; then
  exit 0
fi

/usr/bin/vnstati -m -i red0 -o /var/tmp/bandwidth.png

/usr/sbin/sendmail -t <<EOT
TO: $emailto
FROM: $emailfrom
SUBJECT: Trending over Bandwidth for $(date +%B)
MIME-Version: 1.0
Content-Type: multipart/related;boundary="XYZ"

--XYZ
Content-Type: text/html; charset=ISO-8859-15
Content-Transfer-Encoding: 7bit

<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=ISO-8859-15">
</head>
<body bgcolor="#ffffff" text="#000000">
<img src="cid:bandwidth_image" alt="$(vnstat -m -i red0 --oneline | awk --field-separator ";" '{printf "%s | Used %s",$2,$11}')">
</body>
</html>

--XYZ
Content-Type: image/jpeg;name="bandwidth.png"
Content-Transfer-Encoding: base64
Content-ID: <bandwidth_image>
Content-Disposition: inline; filename="bandwidth.png"

$(base64 /var/tmp/bandwidth.png)
--XYZ--
EOT

rm -rf /var/tmp/bandwidth.png

