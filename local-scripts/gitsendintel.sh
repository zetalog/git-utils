#!/bin/sh

SCRIPT=`dirname \`which gitsendemail.sh\``

GSEFLAGS="\
--smtp-server=smtp.intel.com \
--smtp-server-port=25 \
--from=\"Lv Zheng <lv.zheng@intel.com>\" \
--cc=\"Lv Zheng <lv.zheng@intel.com>\" \
--cc=\"Lv Zheng <zetalog@gmail.com>\" \
"

. $SCRIPT/gitsendemail.sh

