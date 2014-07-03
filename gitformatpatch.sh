#!/bin/sh
#
# Copyright (C) 2014 ZETALOG PERSONAL
# Author: Lv Zheng <zetalog@gmail.com>
#
# Formatting a patchset from git repository with controlled file names and
# subject prefixes.

SCRIPT=`(cd \`dirname $0\`; pwd)`
MSGIDS=$HOME/msgids

GFPFLAGS="-s --thread=shallow --numbered-files"
SUFFIX=.patch
PREFIX=
NUMBER=1
COVER=false
MAJOR=1
MINOR=0

PATCHSTR=PATCH
MAJORSTR=
MINORSTR=

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
	echo "  -n: number of patches to generate from the HEAD"
	echo "  -o: generate outgoing patch with rename/copy detections"
	echo "  -p: specify prefix of patch file format"
	echo "  -s: specify suffix of patch file format, default is .patch"
	echo "  -r: specify major of patch subject format, default is 1"
	echo "  -m: specify minor of patch subject format, default is 0"
	echo "  -t: specify type of patch subject format"
	echo "  Message-Id can be:"
	echo "    none: force starting a new thread, this is default for v1, v0.1"
	echo "    other: Message-Id name in $MSGIDS file"
	echo "Patch file format: [<prefix>]index<suffix>"
	echo "                   index is a width 1-4 integer from 0 to number:"
	echo "                   0 is used for the cover letter."
	echo "                   1-number are used for the patches."
	echo "Patch subject format: [<type> ]PATCH[ v<major>[.<minor>]]"
	exit 0
}

isnumber()
{
	nozero=$2

	if [[ $1 =~ [^0-9] ]]; then
		return 1
	fi
	if [ "x$nozero" = "xyes" -a $1 -le 0 ]; then
		return 1;
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
	n) isnumber $OPTARG yes || fatal "'number' must be an integer (>0): $OPTARG"
	   NUMBER=$OPTARG;;
	o) GFPFLAGS="$GFPFLAGS -M -C";;
	p) PREFIX=$OPTARG;;
	s) SUFFIX=$OPTARG;;
	r) isnumber $OPTARG || fatal "'major' must be an integer (>=0): $OPTARG"
	   MAJOR=$OPTARG;;
	m) isnumber $OPTARG || fatal "'minor' must be an integer (>=0): $OPTARG"
	   MINOR=$OPTARG
	   if [ $MINOR -ne 0 ]; then
		MINORSTR=".$MINOR"
	   fi;;
	t) PATCHSTR="$OPTARG PATCH";;
	?) fatal "Invalid argument: $opt";;
	esac
done
shift $(($OPTIND - 1))

# Sanity checks
if [ $MAJOR -eq 0 -a $MINOR -eq 0 ]; then
	fatal "Patch version is not allowed: v${MAJOR}.${MINOR}."
fi
require_msgid=yes
if [ $MAJOR -eq 1 -a $MINOR -eq 0 ]; then
	require_msgid=no
fi
if [ $MAJOR -eq 0 -a $MINOR -eq 1 ]; then
	require_msgid=no
fi
if [ "x$1" = "x" ]; then
	if [ "x$require_msgid" = "xyes" ]; then
		fatal "Message-Id should be specified for non v1/v0.1 series: v${MAJOR}.${MINOR}."
	fi
elif [ "x$1" != "xnone" ]; then
	if [ "x$require_msgid" = "xno" ]; then
		fatal "Message-Id shouldn't be specified for v${MAJOR}.${MINOR} series: $1."
	fi
#else
	# No sanity check to allow explicit "none" to start a new thread
fi

# Determine width of patch file index
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

# Prepare -x argument of git-format-patch
GFPFLAGS="$GFPFLAGS -$NUMBER"

# Prepare -n --cover-letter argument of git-format-patch
if [ $NUMBER -ge 2 ]; then
	GFPFLAGS="$GFPFLAGS -n"
	if [ "x$COVER" = "xtrue" ]; then
		GFPFLAGS="$GFPFLAGS --cover-letter"
	fi
fi

# Prepare --in-reply-to argument of git-format-patch
if [ "x$1" != "x" -a "x$1" != "xnone" ]; then
	msgid=`cat $MSGIDS | grep $1 | cut -f2`
	if [ "x$msgid" = "x" ]; then
		fatal "Cannot find Message-Id in $MSGIDS: $1."
	fi
	echo "Found Message-Id: <$msgid>."
	GFPFLAGS="$GFPFLAGS --in-reply-to=$msgid"
fi

# Prepare --subject-prefix argument of git-format-patch
if [ $MAJOR -ne 1 -o $MINOR -ne 0 ]; then
	MAJORSTR=" v${MAJOR}"
fi
subject="${PATCHSTR}${MAJORSTR}${MINORSTR}"
GFPFLAGS="$GFPFLAGS --subject-prefix='$subject'"

if [ "x$DRYRUN" != "xyes" ]; then
	indexes=`eval git format-patch $GFPFLAGS`
	echo "Generating $NUMBER patches:"
	echo " file: subject"
	for index in $indexes; do
		file=${PREFIX}`printf %0${WIDTH}d $index`${SUFFIX}
		echo " $file: $subject"
		mv -f $index $file
	done
else
	echo git format-patch $GFPFLAGS
fi

