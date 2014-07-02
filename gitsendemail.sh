#!/bin/sh

usage()
{
	echo ""
	echo "Usage:"
	echo "`basename $0` [-dkgst] <recipients> <file|directory|rev-list>"
	echo ""
	echo "Where:"
	echo "  -d:	dry run"
	echo "  -k:	send email to kernel mailing list"
	echo "  -t:	send email to trivial patch monkey"
	echo "  -s:	send email to stable kernel monkey"
	echo ""
	echo "  recipients can be:"
	echo ""
	echo "  Myself:"
	echo "   lv.zheng:		Lv Zheng <lv.zheng@intel.com>"
	echo "   zetalog:		Lv Zheng <zetalog@gmail.com>"
	echo ""
	echo "  Internal recipients:"
	echo "   patchwork:		Ying Huang <ying.huang@intel.com>"
	echo "   acpi-review:		Intel Linux ACPI team"
	echo "   acpica-review:	Intel Linux ACPICA team"
	echo "   intel-acpi:		Intel Linux ACPI <acpi@linux.intel.com>"
	echo ""
	echo "  External recipients:"
	echo "   linux-acpi:		Linux ACPI <linux-acpi@vger.kernel.org>"
	echo "   linux-kernel:	Linux Kernel <linux-kernel@vger.kernel.org>"
	echo "   acpica-devel:	ACPICA development <devel@acpica.org>"
	echo "   acpica-release:	ACPICA Linux release"
	echo ""
	echo "  Internal patchsets:"
	echo "   intel-uart:		Intel UART patch set reviewers"
	echo "   intel-diverg:	Intel ACPICA divergences reviewers"
	echo ""
	echo "  External patchsets:"
	echo "   acpi-dbgp:		ACPI DBGP patch set reviewers"
	echo "   acpi-uart:		ACPI UART patch set reviewers"
	exit -1
}

if [ "x$AT_HOME" = "xyes" ]; then
	unset https_proxy
	unset http_proxy
	unset ftp_proxy
	unset no_proxy
	unset GIT_PROXY_COMMAND
fi

OUTGOING="no"

while getopts "dkst" opt
do
	case $opt in
	d) DRYRUN="yes";;
	k) GSEFLAGS="$GSEFLAGS \
--cc=\"<linux-kernel@vger.kernel.org>\" \
";;
	s) OUTGOING="yes"
	   GSEFLAGS="$GSEFLAGS \
--cc=\"<stable@vger.kernel.org>\" \
";;
	t) GSEFLAGS="$GSEFLAGS \
--cc=\"<trivial@kernel.org>\" \
";;
	?) echo "Invalid argument $opt"
	   usage;;
	esac
done
shift $(($OPTIND - 1))

if [ "x$1" = "xlv.zheng" ]; then
	echo "Sending email to Lv \"ZETALOG\" Zheng"
	GSEFLAGS="$GSEFLAGS \
--suppress-cc=all \
--to=\"Lv Zheng <lv.zheng@intel.com>\" \
"
elif [ "x$1" = "xzetalog" ]; then
	echo "Sending email to Lv \"ZETALOG\" Zheng"
	GSEFLAGS="$GSEFLAGS \
--suppress-cc=all \
--to=\"Lv Zheng <zetalog@gmail.com>\" \
"
else
	GSELIST="none"

	if [ "x$1" = "xacpica-review" ]; then
		GSEFLAGS="$GSEFLAGS \
--to=\"Robert Moore <robert.moore@intel.com>\" \
--cc=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"David E. Box <david.e.box@intel.com>\" \
--to=\"Yizhe Wang <yizhe.wang@intel.com>\" \
--cc=\"Ying Huang <ying.huang@intel.com>\" \
"
		echo "Sending email to Linux ACPICA team"
	elif [ "x$1" = "xacpi-review" ]; then
		GSEFLAGS="$GSEFLAGS \
--to=\"Rui Zhang <rui.zhang@intel.com>\" \
--to=\"Tianyu Lan <tianyu.lan@intel.com>\" \
--to=\"Aaron Lu <aaron.lu@intel.com>\" \
"
		echo "Sending email to PRC Linux ACPI team"
	elif [ "x$1" = "xlinux-acpi" ]; then
		GSELIST="linux-acpi"
		GSEFLAGS="$GSEFLAGS \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Len Brown <len.brown@intel.com>\" \
--cc=\"linux-acpi@vger.kernel.org\" \
"
		OUTGOING="yes"
		echo "Sending email to Linux ACPI community"
	elif [ "x$1" = "xlinux-kernel" ]; then
		GSELIST="linux-kernel"
		GSEFLAGS="$GSEFLAGS \
--to=\"linux-kernel@vger.kernel.org\" \
--cc=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
"
		OUTGOING="yes"
		echo "Sending email to Linux kernel community"
	elif [ "x$1" = "xacpica-release" ]; then
		GSELIST="acpica-release"
		GSEFLAGS="$GSEFLAGS \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Robert Moore <robert.moore@intel.com>\" \
--to=\"Len Brown <len.brown@intel.com>\" \
--cc=\"linux-acpi@vger.kernel.org\" \
"
		OUTGOING="yes"
		echo "Sending email to ACPICA release related"
	elif [ "x$1" = "xacpica-devel" ]; then
		GSELIST="acpica-devel"
		GSEFLAGS="$GSEFLAGS \
--to=\"Robert Moore <robert.moore@intel.com>\" \
--cc=\"devel@acpica.org\" \
"
		OUTGOING="yes"
		echo "Sending email to ACPICA mailing list"
	elif [ "x$1" = "xintel-acpi" ]; then
		GSELIST="intel-acpi"
		GSEFLAGS="$GSEFLAGS \
--to=\"Len Brown <len.brown@intel.com>\" \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Robert Moore <robert.moore@intel.com>\" \
--to=\"acpi@linux.intel.com\" \
"
		echo "Sending email to Intel ACPI community"
	elif [ "x$1" = "xpatchwork" ]; then
		GSEFLAGS="$GSEFLAGS \
--to=\"Ying Huang <ying.huang@intel.com>\" \
"
		echo "Sending email to PRC ACPI patchwork"
	elif [ "x$1" = "xintel-uart" ]; then
		GSELIST="intel-uart"
		GSEFLAGS="$GSEFLAGS \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Ying Huang <ying.huang@intel.com>\" \
--to=\"Mika Westerberg <mika.westerberg@intel.com>\" \
--to=\"Krogerus Heikki <heikki.krogerus@intel.com>\" \
--to=\"Andriy Shevchenko <andriy.shevchenko@intel.com>\" \
--to=\"Len Brown <len.brown@intel.com>\" \
--to=\"Rui Zhang <rui.zhang@intel.com>\" \
--cc=\"acpi@linux.intel.com\" \
"
		echo "Sending email to Intel UART related"
	elif [ "x$1" = "xacpi-dbgp" ]; then
		GSELIST="acpi-dbgp"
		GSEFLAGS="$GSEFLAGS \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Len Brown <len.brown@intel.com>\" \
--to=\"Thomas Gleixner <tglx@linutronix.de>\" \
--to=\"Ingo Molnar <mingo@redhat.com>\" \
--to=\"H. Peter Anvin <hpa@zytor.com>\" \
--to=\"Jason Wessel <jason.wessel@windriver.com>\" \
--to=\"Feng Tang <feng.tang@intel.com>\" \
--cc=\"linux-acpi@vger.kernel.org\" \
--cc=\"x86@kernel.org\" \
--cc=\"platform-driver-x86@vger.kernel.org\" \
"
		OUTGOING="yes"
		echo "Sending email to ACPI DBGP related"
	elif [ "x$1" = "xacpi-uart" ]; then
		GSELIST="acpi-uart"
		GSEFLAGS="$GSEFLAGS \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Len Brown <len.brown@intel.com>\" \
--to=\"Mika Westerberg <mika.westerberg@intel.com>\" \
--to=\"Krogerus Heikki <heikki.krogerus@intel.com>\" \
--to=\"Greg Kroah-Hartman <gregkh@linuxfoundation.org>\" \
--to=\"Jiri Slaby <jslaby@suse.cz>\" \
--cc=\"linux-acpi@vger.kernel.org\" \
--cc=\"linux-serial@vger.kernel.org\" \
"
		OUTGOING="yes"
		echo "Sending email to ACPI UART related"
	elif [ "x$1" = "xintel-diverg" ]; then
		GSEFLAGS="$GSEFLAGS \
--to=\"Len Brown <len.brown@intel.com>\" \
--to=\"Rafael J. Wysocki <rafael.j.wysocki@intel.com>\" \
--to=\"Robert Moore <robert.moore@intel.com>\" \
--to=\"David E. Box<david.e.box@intel.com>\" \
--cc=\"Ying Huang <ying.huang@intel.com>\" \
--cc=\"Rui Zhang <rui.zhang@intel.com>\" \
--cc=\"Tianyu Lan <tianyu.lan@intel.com>\" \
--cc=\"Aaron Lu <aaron.lu@intel.com>\" \
"
		echo "Sending email to ACPICA divergences related"
	elif [ "x$1" = "xacpica-liyi" ]; then
		GSEFLAGS="$GSEFLAGS \
--to=\"Robert Moore <robert.moore@intel.com>\" \
--to=\"David E. Box <david.e.box@intel.com>\" \
--cc=\"Yi Li <phoenix.liyi@huawei.com>\" \
--cc=\"Ying Huang <ying.huang@intel.com>\" \
"
		echo "Sending email to ACPICA divergences related"
	else
		usage
	fi

	# Cc Ying Huang for internal review
	if [ "x$GSELIST" = "xnone" ]; then
		echo "Sending email to Ying Huang"
		GSEFLAGS="$GSEFLAGS \
--cc=\"Ying Huang <ying.huang@intel.com>\" \
"
	fi
fi

if [ "x$OUTGOING" = "xno" ]; then
	GSEFLAGS="$GSEFLAGS \
--suppress-cc=all \
"
fi

if [ "x$DRYRUN" != "xyes" ]; then
	eval git send-email $GSEFLAGS $2
else
	echo "git send-email \\"
	echo "  $GSEFLAGS \\"
	echo $2
fi

