#!/bin/sh

SCRIPT=`dirname \`which gitsendemail.sh\``

GSEFLAGS="\
--smtp-debug \
--smtp-encryption=tls \
--smtp-server=smtp.gmail.com \
--smtp-server-port=587 \
--smtp-user=zetalog@gmail.com \
--smtp-pass=${GMAIL_PASSWORD} \
--from=\"Lv Zheng <zetalog@gmail.com>\" \
--cc=\"Lv Zheng <zetalog@gmail.com>\" \
--cc=\"Lv Zheng <lv.zheng@intel.com>\" \
"

. $SCRIPT/gitsendemail.sh
