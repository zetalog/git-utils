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

# Option controllable variables
COVER=false
SUFFIX=.patch
PREFIX=
NUMBER=1
MAJOR=1
MINOR=0

# Subject prefix formatting
PATCHSTR=PATCH
MAJORSTR=
MINORSTR=

usage()
{
	echo "Usage: `basename $0` [-d]"
	echo " [-n number] [-c]"
	echo " [-p prefix] [-s suffix]"
	echo " [-r major] [-m minor] [-t type]"
	echo " [-o]"
	echo " [Message-Id]"
	echo "Where:"
	echo "  -d: dry run"
	echo "  -n: specify number of patches to generate from HEAD"
	echo "      default is 1"
	echo "  -c: specify cover letter generation"
	echo "  -p: specify prefix of patch file format"
	echo "  -s: specify suffix of patch file format"
	echo "      default is .patch"
	echo "  -r: specify major of patch subject format"
	echo "      default is 1"
	echo "  -m: specify minor of patch subject format"
	echo "      default is 0"
	echo "  -t: specify type of patch subject format"
	echo "  -o: generate outgoing patch with rename/copy detections"
	echo "  Message-Id can be:"
	echo "      none: force starting a new thread"
	echo "      other: Message-Id name in $MSGIDS file"
	echo "      default none for v1/0.1"
	echo "  Patch file format: [<prefix>]index<suffix>"
	echo "      index is a width 1-4 integer from 0 to number:"
	echo "      0: used for the cover letter"
	echo "      1-number: used for the patches"
	echo "  Patch subject format: [<type> ]PATCH[ v<major>[.<minor>]]"
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
	n) isnumber $OPTARG yes || fatal "Invalid number: $OPTARG isn't an integer >0."
	   NUMBER=$OPTARG;;
	o) GFPFLAGS="$GFPFLAGS -M -C";;
	p) PREFIX=$OPTARG;;
	s) SUFFIX=$OPTARG;;
	r) isnumber $OPTARG || fatal "Invalid major: $OPTARG isn't an integer >=0."
	   MAJOR=$OPTARG;;
	m) isnumber $OPTARG || fatal "Invalid minor: $OPTARG isn't an integer >=0."
	   MINOR=$OPTARG
	   if [ $MINOR -ne 0 ]; then
		MINORSTR=".$MINOR"
	   fi;;
	t) PATCHSTR="$OPTARG PATCH";;
	?) fatal "Invalid option: unknown option $OPTIND.";;
	esac
done
shift $(($OPTIND - 1))

# Sanity checks
if [ $MAJOR -eq 0 -a $MINOR -eq 0 ]; then
	fatal "Invalid major/minor: v${MAJOR}.${MINOR} is not allowed."
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
		fatal "Invalid Message-Id: thread isn't specified for v${MAJOR}.${MINOR}."
	fi
elif [ "x$1" != "xnone" ]; then
	if [ "x$require_msgid" = "xno" ]; then
		fatal "Invalid Message-Id: $1 shouldn't be specified for v${MAJOR}.${MINOR}."
	fi
	msgid=`cat $MSGIDS | grep $1 | cut -f2`
	if [ "x$msgid" = "x" ]; then
		fatal "Invalid Message-Id: cannot find $1 in $MSGIDS."
	fi
#else
	# No sanity check to allow explicit "none" to start a new thread
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
	# Execute git-format-patch
	indexes=`eval git format-patch $GFPFLAGS`

	# Rename patch files
	echo "Generating $NUMBER patches:"
	echo " file: subject"
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
	for index in $indexes; do
		file=${PREFIX}`printf %0${WIDTH}d $index`${SUFFIX}
		echo " $file: $subject"
		mv -f $index $file
	done
else
	echo git format-patch $GFPFLAGS
fi

