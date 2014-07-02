#!/bin/sh

usage()
{
	echo "Usage: `basename $0` [-n num] [-cdo] <Message-Id>"
	echo "Where:"
	echo "  -c: generate cover letter"
	echo "  -d: dry run"
	echo "  -n: top most number of patches to generate"
	echo "  -o: generate outgoing patch with rename/copy detections"
	echo "  -p: specify patch file prefix"
	echo "  -s: specify patch file suffix, default is .patch"
	echo "  Message-Id can be:"
	echo "    none: for the first message in the thread"
	echo "    other: Message-Id name in msgids file"
	exit 0
}

SCRIPT=`(cd \`dirname $0\`; pwd)`
GFPFLAGS="-s -n --thread=shallow"
MSGIDS=$HOME/msgids
SUFFIX=.patch
PREFIX=
NUMBER=1

while getopts "cdn:op:s:" opt
do
	case $opt in
	c) GFPFLAGS="$GFPFLAGS --suffix=.patch --cover-letter --numbered-files";;
	d) DRYRUN="yes";;
	n) GFPFLAGS="$GFPFLAGS -$OPTARG"
	   NUMBER=$OPTARG;;
	o) GFPFLAGS="$GFPFLAGS -M -C";;
	p) PREFIX=$OPTARG;;
	s) SUFFIX=$OPTARG;;
	?) echo "Invalid argument $opt"
	   usage;;
	esac
done
shift $(($OPTIND - 1))

WIDTH=1
if [ $NUMBER -ge 10 ]; then
	WIDTH=2
fi
if [ $NUMBER -ge 100 ]; then
	WIDTH=3
fi
if [ $NUMBER -ge 1000 ]; then
	WIDTH=3
fi

if [ "x$1" = "x" ]; then
	echo "Message-Id is not specified."
	usage
elif [ "x$1" != "xnone" ]; then
	msgid=`cat $MSGIDS | grep $1 | cut -f2`
	echo $msgid
	GFPFLAGS="$GFPFLAGS --in-reply-to=$msgid"
fi

if [ "x$DRYRUN" != "xyes" ]; then
	patches=`eval git format-patch $GFPFLAGS`
	echo "Generating $NUMBER patches:"
	for number in $patches; do
		patch=${PREFIX}`printf %0${WIDTH}d $number`${SUFFIX}
		echo $patch
		mv -f $number $patch
	done
else
	echo git format-patch $GFPFLAGS
fi

