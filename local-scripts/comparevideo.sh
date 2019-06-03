#!/bin/sh

SCRIPT=`(cd \`dirname $0\`; pwd)`

file1=$1
file2=$2
dir1=`(cd \`dirname $file1\`; pwd)`
dir2=`(cd \`dirname $file2\`; pwd)`
base1=`basename $file1`
base2=`basename $file2`

size=32M

if [ "x$dir1" != "x$dir2" ]; then
	echo "Cannot use 2 different top directories:"
	echo "  $dir1"
	echo "  $dir2"
	exit 1
fi

TOP=$dir1
dir1=temp1
dir2=temp2
DIR1=$TOP/$dir1
DIR2=$TOP/$dir2
RESULT=$TOP/result

rm -rf $RESULT
mkdir -p $RESULT

rm -rf $DIR1
mkdir -p $DIR1
cd $DIR1
split -b $size $TOP/$base1
files1=`ls`

rm -rf $DIR2
mkdir -p $DIR2
cd $DIR2
split -b $size $TOP/$base2
files2=`ls`

if [ "x$files1" != "x$files2" ]; then
	echo "Cannot use 2 different sized files:"
	echo "$DIR1/$files1"
	echo "$DIR2/$files2"
	exit 1
fi

FILES=$files1
cd $RESULT

for file in $FILES; do
	hexdump -b $DIR1/$file > $DIR1.hex
	hexdump -b $DIR2/$file > $DIR2.hex
	diff $DIR1.hex $DIR2.hex > $file.diff
	if [ $? = 0 ]; then
		cp -f $DIR1/$file .
	else
		echo "Files are not same: $file"
		echo "< $dir1/$file extracted from $file1"
		echo "> $dir2/$file extracted from $file2"
		cat $file.diff
	fi
	rm -f $DIR1.hex
	rm -f $DIR2.hex
	rm -f $file.diff
done

