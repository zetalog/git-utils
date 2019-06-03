#!/bin/sh

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
ASMDIFF=$CURDIR/vmlinux.o.diff

BINARY=vmlinux.o

BINARY_BEFORE=$LINUX/$BINARY.before
BINARY_AFTER=$LINUX/$BINARY.after
BINARY0=$LINUX/$BINARY
BINARY1=$LINUX/diffvmlinux
BINARY2=$LINUX/diffvmlinux-nosections
BINARY3=$LINUX/diffvmlinux-nosection

echo "Disassembling $BINARY before applying PATCH..."
cp -f $BINARY_BEFORE $BINARY0
cp -f $BINARY0 $BINARY1
cp -f $BINARY1 $BINARY2 && remove_sections $BINARY2 $BINARY3
objdump -d $BINARY2 > $BEFORE

echo "Disassembling $BINARY after applying PATCH..."
cp -f $BINARY_AFTER $BINARY0
cp -f $BINARY0 $BINARY1
cp -f $BINARY1 $BINARY2 && remove_sections $BINARY2 $BINARY3
objdump -d $BINARY2 > $AFTER

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
