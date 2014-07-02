#!/bin/sh

usage() {
	echo "Usage:"
	echo "`basename $0` [-o object] [before after]"
	echo "Where:"
	echo "before: Specify an object file 1 to compare."
	echo "after:  Specify an object file 2 to compare."
	echo "object: Specify the object file prefix to compare, default is vmlinux.o."
	echo "        The following two object files should be in current directory:"
	echo "          vmlinux.o.before"
	echo "          vmlinux.o.after"
}

fatal_usage() {
	usage
	exit -1
}

# FIXME: More Useless Sections
#
# Please add other sections that would appear as executable but should get 
# removed for the comparision.
USELESS_SECTIONS=".notes"

remove_sections() {
	binary2=$1
	binary3=$2

	for section in $USELESS_SECTIONS; do
		echo "Removing $section section..."
		objcopy -R $section $binary2 $binary3
		mv $binary3 $binary2
	done
}

CURDIR=`pwd`
LINUX=$CURDIR
AFTER=$CURDIR/after.dump
BEFORE=$CURDIR/before.dump

while getopts "o:" opt
do
	case $opt in
	o) BINARY=$OPTARG;;
	?) echo "Invalid argument $opt"
	   fatal_usage;;
	esac
done
shift $(($OPTIND - 1))

if [ "x$BINARY" = "x" ]; then
	BINARY=vmlinux.o
fi

if [ "x$1" = "x" -o "x$2" = "x" ]; then
	BINARY_BEFORE=$LINUX/$BINARY.before
	BINARY_AFTER=$LINUX/$BINARY.after
	ASMDIFF=$CURDIR/$BINARY.diff
else
	BINARY_BEFORE=$1
	BINARY_AFTER=$2
	ASMDIFF=$CURDIR/object.diff
fi

BINARY0=$LINUX/$BINARY
BINARY1=$LINUX/diffvmlinux
BINARY2=$LINUX/diffvmlinux-nosections
BINARY3=$LINUX/diffvmlinux-nosection

echo "Disassembling $BINARY before applying PATCH..."
cp -f $BINARY_BEFORE $BINARY0
cp -f $BINARY0 $BINARY1
cp -f $BINARY1 $BINARY2 && remove_sections $BINARY2 $BINARY3
objdump -d $BINARY2 > $BEFORE
sed 's/^ [0-9a-fA-F]*\://g' $BEFORE > tmp
mv tmp $BEFORE

echo "Disassembling $BINARY after applying PATCH..."
cp -f $BINARY_AFTER $BINARY0
cp -f $BINARY0 $BINARY1
cp -f $BINARY1 $BINARY2 && remove_sections $BINARY2 $BINARY3
objdump -d $BINARY2 > $AFTER
sed 's/^ [0-9a-fA-F]*\://g' $AFTER > tmp
mv tmp $AFTER

# XXX: Fatal Error for the Sub-shell
#
# We'll reach here even in the case of fatal due to the sub-shell.
# Thus we do cleanup here and the relative path of ASMDIFF is correct.

if [ -f $BEFORE ] && [ -f $AFTER ]; then
	echo "Generating assembly differences..."
	diff -u $BEFORE $AFTER > $ASMDIFF
	echo "$ASMDIFF is ready."
fi

rm -f $BINARY1
rm -f $BINARY2
rm -f $BINARY3
#rm -f $BEFORE
#rm -f $AFTER
