#!/bin/sh

SCRIPT=`(cd \`dirname $0\`; pwd)`
MSGIDS=$HOME/msgids
GFPFLAGS="-s --thread=shallow --numbered-files"
SUFFIX=.patch
PREFIX=
NUMBER=1
COVER=false
MAJOR=1
MINOR=0
MINORSTR=
TYPE=PATCH

usage()
{
	echo "Usage: `basename $0`"
	echo " [-n number] [-c] [-o]"
	echo " [-p prefix] [-s suffix]"
	echo " [-r major] [-m minor] [-t type]"
	echo " [-d] [Message-Id]"
	echo "Where:"
	echo "  -d: dry run"
	echo "  -c: generate cover letter"
	echo "  -n: top most number of patches to generate"
	echo "  -o: generate outgoing patch with rename/copy detections"
	echo "  -p: specify patch file prefix"
	echo "  -s: specify patch file suffix, default is .patch"
	echo "  -r: specify patch major version, to form [PATCH v<major>], default is 1"
	echo "  -m: specify patch minor version, to form [PATCH v<major>.<minor>], default is 0"
	echo "  -t: specify patch type, to form [<type> PATCH]"
	echo "  Message-Id can be:"
	echo "    none: for the first message in the thread, this is default for v1, v0.1"
	echo "    other: Message-Id name in $MSGIDS file"
	exit 0
}

isnumber()
{
	if [[ $1 =~ [^0-9] ]]; then
		return 1
	fi
	return 0
}

fatal()
{
	echo
	echo "Fatal error:"
	echo $1
	echo
	usage
}

while getopts "cdn:op:s:r:m:t:" opt
do
	case $opt in
	c) COVER=true;;
	d) DRYRUN="yes";;
	n) isnumber $OPTARG || fatal "Argument of -n must be a positive integer: $OPTARG"
	   if [ $OPTARG -le 0 ]; then
		fatal "Argument of -n must be greater than 0: $OPTARG"
	   fi
	   NUMBER=$OPTARG;;
	o) GFPFLAGS="$GFPFLAGS -M -C";;
	p) PREFIX=$OPTARG;;
	s) SUFFIX=$OPTARG;;
	r) isnumber $OPTARG || fatal "Argument of -r must be a positive integer: $OPTARG"
	   MAJOR=$OPTARG;;
	m) isnumber $OPTARG || fatal "Argument of -m must be a positive integer: $OPTARG"
	   MINOR=$OPTARG
	   if [ $MINOR -ne 0 ]; then
		MINORSTR=".$MINOR"
	   fi;;
	t) TYPE="$OPTARG PATCH";;
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
if [ $NUMBER -ge 2 ]; then
	GFPFLAGS="$GFPFLAGS -n"
	if [ "x$COVER" = "xtrue" ]; then
		GFPFLAGS="$GFPFLAGS --cover-letter"
	fi
fi
GFPFLAGS="$GFPFLAGS -$NUMBER"

if [ "x$1" = "x" ]; then
	if [ $MAJOR -eq 1 -a $MINOR -eq 0 ]; then
		fatal "Message-Id is not specified for non v1 series."
	fi
	if [ $MAJOR -eq 0 -a $MINOR -eq 1 ]; then
		fatal "Message-Id is not specified for non v0.1 series."
	fi
elif [ "x$1" != "xnone" ]; then
	if [ $MAJOR -eq 1 -a $MINOR -eq 0 ]; then
		fatal "Message-Id is specified without specifying >1 version (-r/-m): $1."
	fi
	if [ $MAJOR -eq 0 -a $MINOR -eq 1 ]; then
		fatal "Message-Id $1 is specified without specifying >0.1 version (-r/-m): $1."
	fi
	msgid=`cat $MSGIDS | grep $1 | cut -f2`
	if [ "x$msgid" = "x" ]; then
		fatal "Cannot find Message-Id in $MSGIDS: $1."
	fi
	echo "Found Message-Id: <$msgid>"
	GFPFLAGS="$GFPFLAGS --in-reply-to=$msgid"
fi
if [ $MAJOR -eq 1 -a $MINOR -eq 0 ]; then
	GFPFLAGS="$GFPFLAGS --subject-prefix='$TYPE'"
else
	GFPFLAGS="$GFPFLAGS --subject-prefix='$TYPE v${MAJOR}${MINORSTR}'"
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

