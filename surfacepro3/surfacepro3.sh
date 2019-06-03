#!/bin/sh

SCRIPT=`(cd \`dirname $0\`; pwd)`

#sudo cp -f ${SCRIPT}/surfacepro3.hwdb /etc/udev/hwdb.d/surfacepro3.hwdb
sudo udevadm hwdb --update
#sudo udevadm test /sys/class/input/event0

