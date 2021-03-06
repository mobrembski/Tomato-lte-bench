#!/bin/sh
# ftptest.sh - FTP server statistics
#
# Copyright 2016 Michał Obrembski
cd `dirname $0`
. common_rrd.sh

function checkFTPFile {
	FTP_ANON_ROOT=`nvram get ftp_anonroot`

	if [ $? -eq 1 ]; then
		echo "Cannot get where ftp anonymous root is"
		exit 1
	fi

	if [ ! -e $FTP_ANON_ROOT/testfile ]
	then
		echo "Creating 35MB FTP Test file"
		dd if=/dev/urandom of=$FTP_ANON_ROOT/testfile bs=1M count=35
	fi
}

function create {
	if [ ! -e $db ]
	then
	    echo "Database not found, creating a new one..."
	    $rrdtool create $db --step 900 \
	    DS:download:GAUGE:2700:0:U \
	    DS:upload:GAUGE:2700:0:U \
	    RRA:AVERAGE:0.5:1:120 \
	    RRA:AVERAGE:0.5:6:90 \
	    RRA:AVERAGE:0.5:40:50 \
	    RRA:AVERAGE:0.5:100:20
	fi
}

function update {
	echo "Testing ftp server test"
	db=$DBFOLDER$'/ftptest.rrd'
	checkFTPFile
	create

	downloaded=`cat /var/log/messages | grep ftp | grep DOWNLOAD | tail -n 1 | grep -o '[0-9.]\+Kbyte/sec'`
	downloaded=${downloaded%Kbyte/sec}
	uploaded=`cat /var/log/messages | grep ftp | grep UPLOAD | tail -n 1 | grep -o '[0-9.]\+Kbyte/sec'`
	uploaded=${uploaded%Kbyte/sec}
	$rrdtool update $db -t download:upload N:$downloaded:$uploaded
	LOGLINE=`date`" Download: "$downloaded"KBps Upload: "$uploaded"KBps"
	echo $LOGLINE >> $LOGFOLDER/ftptest.log
	echo $LOGLINE
}

function graph {
	local period=$1
	echo "Generating ftptest graph for period "$period
	db=$DBFOLDER$'/ftptest.rrd'

	$rrdtool graph $IMGFOLDER/ftptest-$period.png -s -1$period \
	-t "FTP Test in $period" \
	--height $RRDHEIGHT \
	--width $RRDWIDTH \
	$OPTS \
	$CUST_COLOR \
	-l 0 -v "Mb/s" \
	DEF:downdb=$db:download:AVERAGE \
	DEF:updb=$db:upload:AVERAGE \
	CDEF:download=downdb,8000,* \
	CDEF:upload=updb,8000,* \
	VDEF:minin=upload,MINIMUM \
	VDEF:minout=download,MINIMUM \
	VDEF:maxin=upload,MAXIMUM \
	VDEF:maxout=download,MAXIMUM \
	VDEF:avgin=upload,AVERAGE \
	VDEF:avgout=download,AVERAGE \
	VDEF:lstin=upload,LAST \
	VDEF:lstout=download,LAST \
	VDEF:totin=upload,TOTAL \
	VDEF:totout=download,TOTAL \
	"COMMENT: \l" \
	"COMMENT:                    " \
	"COMMENT:Minimum      " \
	"COMMENT:Maximum      " \
	"COMMENT:Average      " \
	"COMMENT:Current      \l" \
	"COMMENT:   " \
	"AREA:download#EDA362:Download  " \
	"LINE1:download#F47200" \
	"GPRINT:minout:%5.1lf %sb/s   " \
	"GPRINT:maxout:%5.1lf %sb/s   " \
	"GPRINT:avgout:%5.1lf %sb/s   " \
	"GPRINT:lstout:%5.1lf %sb/s \l" \
	"COMMENT:   " \
	"AREA:upload#8AD3F1:Upload    " \
	"LINE1:upload#49BEEF" \
	"GPRINT:minin:%5.1lf %sb/s   " \
	"GPRINT:maxin:%5.1lf %sb/s   " \
	"GPRINT:avgin:%5.1lf %sb/s   " \
	"GPRINT:lstin:%5.1lf %sb/s  \l" > /dev/null
}
