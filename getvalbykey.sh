#!/bin/sh

SCRIPT=`(cd \`dirname $0\`; pwd)`
cat $HOME/$1 | grep $2 | cut -f2

