#!/bin/bash

if [ "x$1" = "xconfig-cui" ]; then
	echo "Configuring console mode."
	sudo systemctl set-default multi-user.target
	exit 0
fi
if [ "x$1" = "xstart-gui" ]; then
	echo "Starting lightdm."
	sudo systemctl start lightdm
	exit 0
fi
if [ "x$1" = "xstop-gui" ]; then
	echo "Stopping lightdm."
	sudo systemctl stop lightdm
	exit 0
fi

echo "Wrong option, please specify one of the followings:"
echo "config-cui: configure console mode"
echo "start-gui:  start lightdm"
echo "stop-gui:   stop lightdm"
exit 1
