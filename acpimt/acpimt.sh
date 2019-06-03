#!/bin/bash
#
# Copyright (C) 2017 Intel Corporation
# Author: 2017 Lv Zheng <lv.zheng@intel.com>
#
# NAME:
#         acpimt.sh - launch multi-threads running Linux kernel ACPI
#                     transactions.
#
# SYNOPSIS:
#         acpimt.sh [-c amlfile]
#                   [-e acpiname]
#                   [-f acpifile]
#                   [-m kernel_module]
#                   [-d acpidbg] [-t seconds]
#
# DESCRIPTION:
#         This program is used as a test facility validating multi-thread
#         support in Linux ACPI subsystem. It can launch ACPI transactions
#         as test cases using child processes and executes them in parallel
#         endlessly. Test processes can be terminated by Ctrl-C.
#
#         The launchable tests can be:
#          -c: Use /sys/kernel/debug/acpi/custom_method to customize
#              control methods (CONFIG_ACPI_CUSTOM_METHOD) repeatedly.
#          -e: Use acpidbg to evaluate a named object w/o arguments
#              (CONFIG_ACPI_DEBUGGER_USER) repeatedly.
#          -f: Use cat to read a sysfs/procfs file repeatedly.
#          -m: Use modprobe to load/unload a module repeatedly.
#
#         Options:
#          -d: Full path to acpidbg (in case it cannot be reached via
#              %PATH%.
#          -t: Seconds to sleep between test operations.

########################################################################
# Global Settings
########################################################################
SLEEPSEC=10
TEMPFILE=`mktemp`
ACPIDBG=acpidbg
ACPINAMES=
ACPIFILES=
AMLFILES=
KERNMODS=

########################################################################
# Usages
########################################################################
usage() {
	echo "Usage: `basename $0` [-d acpidbg] [-t second]"
	echo "                     [-c amlfile]"
	echo "                     [-e acpiname]"
	echo "                     [-f acpifile]"
	echo "                     [-m kernel_module]"
	echo ""
	echo "This program is used as a test facility validating multi-thread"
	echo "support in Linux ACPI subsystem. It can launch ACPI transactions"
	echo "as test cases using child processes and executes them in parallel"
	echo "endlessly. Test processes can be terminated by Ctrl-C."
	echo ""
	echo "Test cases are:"
	echo "-c: Use /sys/kernel/debug/acpi/custom_method to customize"
	echo "    control methods (CONFIG_ACPI_CUSTOM_METHOD) repeatedly."
	echo "-e: Use acpidbg to evaluate a named object w/o arguments"
	echo "    (CONFIG_ACPI_DEBUGGER_USER) repeatedly."
	echo "-f: Use cat to read a sysfs/procfs file repeatedly."
	echo "-m: Use modprobe to load/unload a module repeatedly."
	echo ""
	echo "Options are:"
	echo "-d: Full path to acpidbg (in case it cannot be reached via"
	echo "    %PATH%."
	echo "-t: Seconds to sleep between test operations."
}

fatal_usage() {
	usage
	exit 1
}

########################################################################
# Loadable Module
########################################################################
find_module() {
	curr_modules=`lsmod | cut -d " " -f1`

	for m in $curr_modules; do
		if [ "x$m" = "x$1" ]; then
			return 0
		fi
	done
	return 1
}

remove_module() {
	find_module $1
	if [ $? -eq 0 ]; then
		echo "Removing $1 ..."
		modprobe -r $1
		if [ $? -ne 0 ]; then
			echo "Failed to rmmod $1."
			return 1
		fi
	fi
	return 0
}

insert_module() {
	find_module $1
	if [ $? -ne 0 ]; then
		echo "Inserting $1 ..."
		modprobe $1
		if [ $? -ne 0 ]; then
			echo "Failed to insmod $1."
			return 1
		fi
	fi
	return 0
}

########################################################################
# Endless Test Control
########################################################################
endless_term1() {
	echo "Terminating parent process..."
	echo "stop" > $TEMPFILE
}

endless_term2() {
	echo "stopped" > $TEMPFILE
}

endless_stop1() {
	if [ ! -f $TEMPFILE ]; then
		return 0
	fi
	cat $TEMPFILE | grep "stop" > /dev/null
}

endless_stop2() {
	if [ ! -f $TEMPFILE ]; then
		return 0
	fi
	cat $TEMPFILE | grep "stopped" > /dev/null
}

endless_exit() {
	wait
	remove_module acpi_dbg
	rm -f $TEMPFILE
}

endless_init() {
	echo > $TEMPFILE
	if [ ! -d /sys/kernel/debug/acpi ]; then
		mount -t debugfs none /sys/kernel/debug
	fi
	if [ ! -x $ACPIDBG ]; then
		echo "$ACPIDBG is not executable."
		return 1
	fi
	if [ ! -f /sys/kernel/debug/acpi/custom_method ]; then
		echo "ACPI_CUSTOM_METHOD is not configured."
		return 1
	fi
	insert_module acpi_dbg || return 1
	trap endless_term1 2 3 15
}

########################################################################
# Test Facility - Namespace Object Evaluation
########################################################################
acpieval() {
	while :
	do
		endless_stop1
		if [ $? -eq 0 ]; then
			echo "Terminating child process - acpieval $1..."
			break
		fi
		echo "-----------------------------------"
		echo "evaluate $1"
		$ACPIDBG -b "ex $1"
		echo "-----------------------------------"
		sleep $SLEEPSEC
	done
	endless_term2
}

########################################################################
# Test Facility - Method Customization
########################################################################
acpicust() {
	while :
	do
		endless_stop1
		if [ $? -eq 0 ]; then
			echo "Terminating child process - acpicust $1..."
			break
		fi
		echo "==================================="
		echo "customize $1"
		cat $1 > /sys/kernel/debug/acpi/custom_method
		echo "==================================="
		sleep $SLEEPSEC
	done
	endless_term2
}

########################################################################
# Test Facility - Kernel Exported Files
########################################################################
acpicat() {
	while :
	do
		endless_stop1
		if [ $? -eq 0 ]; then
			echo "Terminating child process - acpicat $1..."
			break
		fi
		echo "+++++++++++++++++++++++++++++++++++"
		echo "concatenate $1"
		cat $1
		echo "+++++++++++++++++++++++++++++++++++"
		sleep $SLEEPSEC
	done
	endless_term2
}

########################################################################
# Test Facility - Dynamic Module Load/Unload
########################################################################
acpimod() {
	res=0
	while :
	do
		endless_stop1
		if [ $? -eq 0 ]; then
			echo "Terminating child process - acpimod $1..."
			break
		fi
		find_module $1
		if [ $? -eq 0 ]; then
			echo "***********************************"
			echo "remove $1"
	 		remove_module $1
			res=$?
			echo "***********************************"
			if [ $res -ne 0 ]; then
				echo "Terminated child process - acpimod $1 (rmmod)."
				exit
			fi
		else
			echo "***********************************"
			echo "insert $1"
			insert_module $1
			res=$?
			echo "***********************************"
			if [ $res -ne 0 ]; then
				echo "Terminated child process - acpimod $1 (insmod)."
				exit
			fi
		fi
		sleep $SLEEPSEC
	done
	endless_term2
}

########################################################################
# Script Entry Point
########################################################################
while getopts "c:d:e:f:hm:t:" opt
do
	case $opt in
	c) AMLFILES="$AMLFILES $OPTARG";;
	e) ACPINAMES="$ACPINAMES $OPTARG";;
	d) ACPIDBG=$OPTARG;;
	f) ACPIFILES="$ACPIFILES $OPTARG";;
	m) KERNMODS="$KERNMODS $OPTARG";;
	t) SLEEPSEC=$OPTARG;;
	h) usage;;
	?) fatal_usage;;
	esac
done
shift $(($OPTIND - 1))

# Startup
endless_init || exit 2

# Perform sanity checks
for amlfile in $AMLFILES; do
	if [ ! -f $amlfile ]; then
		echo "$amlfile is missing."
		exit 1
	fi
done
for acpifile in $ACPIFILES; do
	if [ ! -f $acpifile ]; then
		echo "$acpifile is missing."
		exit 1
	fi
done

# Lauch test cases
for amlfile in $AMLFILES; do
	acpicust $amlfile &
done
for acpiname in $ACPINAMES; do
	acpieval $acpiname &
done
for acpifile in $ACPIFILES; do
	acpicat $acpifile &
done
for kmod in $KERNMODS; do
	acpimod $kmod &
done

# Wait children
while :
do
	endless_stop2
	if [ $? -eq 0 ]; then
		echo "Terminated parent process."
		break
	fi
	endless_stop1
	if [ $? -eq 0 ]; then
		sleep $SLEEPSEC
		echo "Force terminating parent process..."
		endless_term2
	else
		sleep $SLEEPSEC
	fi
done

# Cleanup
endless_exit
