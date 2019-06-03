#!/bin/sh

SCRIPT=`(cd \`dirname $0\`; pwd)`

sudo ${SCRIPT}/acpimt.sh \
	-t 10 \
	-d ~/workspace/linux-acpica/tools/power/acpi/acpidbg \
	-e _SB.PCI0.SBRG.LID0._LID \
	-f /proc/acpi/button/lid/LID0/state \
	-m button \

	#-f /sys/class/power_supply/AC0/online \
	#-f /sys/class/power_supply/BAT0/status \
	#-m acpi_ipmi \
	#-c oem1.aml \
	#-m acpi_dbg \
	#-f /sys/class/power_supply/BAT0/voltage_now \
	#-f /sys/class/power_supply/BAT0/current_now \
