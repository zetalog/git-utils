#!/bin/sh
#
# Copyright (c) 2012, Intel Corporation
# Author: Lv Zheng <lv.zheng@intel.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; version 2 of the License.
#
# NAME
#   checkacpica.sh - Generating coding style checking report by running
#                    scripts/checkpatch.pl for ACPICA
# SYNOPSIS
#   checkacpica.sh [-t] <linux-dir>


# Default checkpatch.pl options
CPFLAGS="-f"

fulldir() {
	lpath=$1
	(
		cd $lpath; pwd
	)
}

getdir() {
	lpath=`dirname $1`
	fulldir $lpath
}

fatal() {
	echo $1
	exit -1
}

usage() {
	echo "Usage: `basename $0` [-t] <linux>"
	echo "Where:"
	echo "    -t: Generate report per line - terse."
	echo " linux: Specify Linux source tree."
}

fatal_usage() {
	usage
	exit -1
}

checkfile() {
	scripts/checkpatch.pl $CPFLAGS $1 2>/dev/null
}

checkdir() {
	lfiles=`ls $1/*.h 2>/dev/null`
	for f in $lfiles; do
		checkfile $f
	done
	lfiles=`ls $1/*.c 2>/dev/null`
	for f in $lfiles; do
		checkfile $f
	done
}

checkacpica() {
	ACPICA_DIRS="drivers/acpi/acpica include/acpi include/acpi/platform"

	# Committed styles:
	#
	# return is not a function, parentheses are not required
	# braces {} are not necessary for single statement blocks
	# labels should not be indented

	for d in $ACPICA_DIRS; do
		checkdir $d | awk '!\
/return is not a function, parentheses are not required|\
braces {} are not necessary for single statement blocks|\
labels should not be indented/\
 {print}'
	done
}

while getopts "t" opt
do
	case $opt in
	t) CPFLAGS="--no-summary --terse $CPFLAGS";;
	?) echo "Invalid argument $opt"
	   fatal_usage;;
	esac
done
shift $(($OPTIND - 1))

CURDIR=`pwd`
LINUX=`getdir $1`

(
	cd $LINUX
	checkacpica
)
