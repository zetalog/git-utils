#!/bin/sh

if [ "x$1" = "x" ]; then
	echo "No version specified"
	exit 1
fi
ver=$1
sudo rm -rf /lib/modules/${ver}*
sudo rm -f /boot/*${ver}*
make -j64 | tee build.log 2>&1
sudo make modules_install install
