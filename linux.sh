#!/bin/sh
#
# Copyright (C) 2014 ZETALOG PERSONAL
# Author: Lv Zheng <zetalog@gmail.com>
#
# Typical build configuration file contents:
# ######################
# # LINUX_VER=acpica   #
# # LINUX_ARCH=x86     #
# # LINUX_SUBARCH=i386 #
# # LINUX_MACH=z530    #
# # LINUX_TOOLS=acpi   #
# ######################
# It should locate at:
# $SCRIPT/defconfig/build
# Then:
# The kconfig file should locate at:
# $SCRIPT/defconfig/linux-config-acpica-z530
# The customized DSDT should locate at:
# $SCRIPT/defconfig/dsdt.hex-z530
# The Linux kernel source should locate at:
# $SCRIPT/workspace/linux-acpica
# And, the following kernel tools will be built:
# acpi
#
# Typical special config test file contents:
# #################
# # CONFIG_ACPI=n #
# #################
# It should locate at:
# $SCRIPT/defconfig/test
# This allows additional build test to be performed by disabling ACPI.
#
# Typical special object test file contents:
# ######################################
# # arch/x86/pci/mmconfig-shared.o     #
# # drivers/firmware/iscsi_ibft_find.o #
# # drivers/sfi/sfi_acpi.o             #
# ######################################
# It should locate at:
# $SCRIPT/defconfig/test
# This allows additional make targets to be performed.

usage()
{
	echo "Usage: `basename $0` [-b build] [-c config] [-o object] [-p thread] [-q patch] [-r rebuild] [-isw] [-ynm] [-dv]"
	echo "Where:"
	echo "  -b: specify build configuration file"
	echo "  -c: specify special config test file"
	echo "  -o: specify special object test file"
	echo "  -y: build allyesconfig"
	echo "  -n: build allnoconfig"
	echo "  -m: build allmodconfig"
	echo "  -p: specify parallel build threads"
	echo "  -r: enable rebuilding"
	echo "      no: never enable rebuilding"
	echo "      yes: always enable rebuilding"
	echo "  -s: increase checker level (max 2, C=1, C=2)"
	echo "  -w: increase warning level (max 3, W=1, W=2, W=3)"
	echo "  -i: prepare disk images"
	echo "  -d: dry run"
	echo "  -v: increase verbose level (max 3, V=0, V=1, V=2)"
	echo "  -q: test and sign quilt patch"
	exit 0
}

load_objects()
{
	objs=`cat $1`
	SOBJTESTS="$SOBJTESTS $objs"
}

modify_kconfig()
{
	if [ "x$1" =  "x--disable" ]; then
		echo " Disabling $2"
	else
		echo " Enabling $2"
	fi
	$MODCONFIG $@
	make oldconfig 1>/dev/null 2>&1
	cfg=`cat ./.config | grep ^CONFIG_$2=`
	if [ "x$1" =  "x--disable" ]; then
		if [ "x$cfg" != "x" ]; then
			echo "Failed to disable $2, please check dependencies."
			exit 1
		fi
	else
		if [ "x$cfg" = "x" ]; then
			echo "Failed to enable $2, please check dependencies."
			exit 1
		fi
	fi
}

copy_configs()
{
	echo "Copying $LINUX_CFG"
	if [ "x$DRYRUN" != "xyes" ]; then
		rm -f $KERNELIMG
		cp -f $LINUX_CFG $KERNELCFG
	fi
	if [ "x$CUSTOM_DSDT" != "x" ]; then
		if [ -f $CUSTOM_DSDT ]; then
			echo "Copying $CUSTOM_DSDT"
			if [ "x$DRYRUN" != "xyes" ]; then
				cp -f $CUSTOM_DSDT $KERNELDSDT
				apply_kconfig CONFIG_ACPI_CUSTOM_DSDT_FILE=\"acpi/dsdt.hex\"
			fi
		fi 
	fi
}

save_status()
{
	echo > $STATUS
	echo VER=$LINUX_VER >> $STATUS
	echo ARCH=$LINUX_ARCH >> $STATUS
	echo SUBARCH=$LINUX_SUBARCH >> $STATUS
	echo MACH=$LINUX_MACH >> $STATUS
	echo TEST=$1 >> $STATUS
	echo COMMIT=$COMMIT >> $STATUS
	echo PATCH=$QUILTPATCH >> $STATUS
}

build_objects()
{
	log=$LINUX_VER-$LINUX_MACH-$1-$QUILTPATCH.log

	for obj in $SOBJTESTS; do
		echo "=============================="
		echo "Testing special object $obj"
		echo "=============================="
		if [ "x$DRYRUN" != "xyes" ]; then
			rm -f $obj
			echo "==========" >>$log
			echo "Testing $obj" >>$log
			echo "==========" >>$log
			if [ "x$VERBOSE" != "x" ]; then
				make $MAKEFLAGS ARCH=$BUILD_ARCH $obj 2>&1 | tee -a $log
			else
				make $MAKEFLAGS ARCH=$BUILD_ARCH $obj 2>&1 >>$log
			fi
		else
			echo make $MAKEFLAGS ARCH=$BUILD_ARCH $obj
		fi
	done
}

build_tool()
{
	tlog=$LINUX_VER-$LINUX_MACH.log
	t=$1
	d=$2

	if [ "x$1" = "xdefault" ]; then
		echo "==========" >>$tlog
		echo "Building tools-$t" >>$tlog
		echo "==========" >>$tlog
		if [ "x$REBUILD" = "xyes" ]; then
			make ${t}_clean
		fi
		if [ "x$VERBOSE" != "x" ]; then
			make DEBUG=$d $MAKEFLAGS $t 2>&1 | tee -a $tlog
		else
			make DEBUG=$d $MAKEFLAGS $t 2>&1 >>$tlog
		fi

		echo "==========" >>$tlog
		echo "Installing tools-$t to $ROOTFS" >>$tlog
		echo "==========" >>$tlog
		if [ "x$VERBOSE" != "x" ]; then
			make ${t}_uninstall DESTDIR=$ROOTFS 2>&1 | tee -a $tlog
			make ${t}_install DESTDIR=$ROOTFS 2>&1 | tee -a $tlog
		else
			make ${t}_uninstall DESTDIR=$ROOTFS >>$tlog
			make ${t}_install DESTDIR=$ROOTFS >>$tlog
		fi
	else
		echo "=========="
		echo "Building tools-$t"
		echo "=========="
		if [ "x$REBUILD" = "xyes" ]; then
			echo make ${t}_clean
		fi
		echo make DEBUG=$d $MAKEFLAGS $t

		echo "=========="
		echo "Installing tools-$t to $ROOTFS"
		echo "=========="
		echo make ${t}_uninstall DESTDIR=$ROOTFS
		echo make ${t}_install DESTDIR=$ROOTFS
	fi
}

build_kernel()
{
	tlog=$LINUX_VER-$LINUX_MACH.log
	log=$LINUX_VER-$LINUX_MACH-$1-$QUILTPATCH.log

	save_status $1

	echo > $tlog
	if [ "x$1" = "xdefault" ]; then
	(
		cd tools
		for t in $LINUX_TOOLS; do
			build_tool $t false
			build_tool $t true
		done
	)
	fi

	if [ "x$DRYRUN" != "xyes" ]; then
		echo "==========" >>$tlog
		echo "Building kernel" >>$tlog
		echo "==========" >>$tlog
		make ARCH=$BUILD_ARCH oldconfig
		apply_kconfig CONFIG_STAGING=n
		if [ "x$REBUILD" = "xyes" ]; then
			make ARCH=$BUILD_ARCH clean
		fi
		if [ "x$VERBOSE" != "x" ]; then
			make $MAKEFLAGS ARCH=$BUILD_ARCH 2>&1 | tee -a $tlog
		else
			make $MAKEFLAGS ARCH=$BUILD_ARCH 2>&1 >>$tlog
		fi

		echo "==========" >>$tlog
		echo "Installing kernel to $ROOTFS" >>$tlog
		echo "==========" >>$tlog
		if [ "x$VERBOSE" != "x" ]; then
			make ARCH=$BUILD_ARCH INSTALL_MOD_PATH=$ROOTFS modules_install 2>&1 | tee -a $tlog
			make ARCH=$BUILD_ARCH INSTALL_PATH=$ROOTFS install 2>&1 | tee -a $tlog
		else
			make ARCH=$BUILD_ARCH INSTALL_MOD_PATH=$ROOTFS modules_install 2>&1 >>$tlog
			make ARCH=$BUILD_ARCH INSTALL_PATH=$ROOTFS install 2>&1 >>$tlog
		fi

		mv $tlog $log
		if [ -f $KERNELIMG ]; then
			echo "Building linux-$LINUX_VER-$LINUX_MACH success."
		else
			BUILDFAIL=yes
			echo "Building linux-$LINUX_VER-$LINUX_MACH failure."
		fi
	else
		echo "=========="
		echo "Building kernel"
		echo "=========="
		echo make ARCH=$BUILD_ARCH oldconfig
		echo apply_kconfig CONFIG_STAGING=n
		if [ "x$REBUILD" = "xyes" ]; then
			echo make ARCH=$BUILD_ARCH clean
		fi
		echo make $MAKEFLAGS ARCH=$BUILD_ARCH

		echo "=========="
		echo "Installing kernel to $ROOTFS"
		echo "=========="
		echo make ARCH=$BUILD_ARCH INSTALL_MOD_PATH=$ROOTFS modules_install
		echo make ARCH=$BUILD_ARCH INSTALL_PATH=$ROOTFS install
	fi

	build_objects $1
}

parse_kconfig()
{
	echo $@ | awk 'NR==1{							\
		space=" ";							\
		if (match($0, /^CONFIG_/)) {					\
			rem=substr($0, RLENGTH+1);				\
			if (match(rem, /[A-Za-z0-9_]+=/)) {			\
				cfg=substr(rem, 0, RLENGTH);			\
				val=substr(rem, RLENGTH+1);			\
				if (match(val, /y/)) {				\
					opt="--enable";		 		\
					cmds=opt""space""cfg;			\
				} else if (match(val, /n/)) {			\
					opt="--disable";			\
					cmds=opt""space""cfg;			\
				} else if (match(val, /m/)) {			\
					opt="--module";				\
					cmds=opt""space""cfg;			\
				} else if (match(val, /^[0-9]+$/)) {		\
					opt="--set-val";			\
					cmds=opt""space""cfg""space""val;	\
				} else if (match(val, /^\".*\"$/)) {		\
					str=substr(val, 2, RLENGTH-2);		\
					opt="--set-str";			\
					cmds=opt""space""cfg""space""str;	\
				} else {					\
					opt="--set-val";			\
					cmds=opt""space""cfg""space""val;	\
				}						\
				print cmds;					\
			}							\
		}								\
	}'
}

apply_kconfig()
{
	param=`parse_kconfig $@`
	modify_kconfig $param
}

apply_kconfig_file()
{
	while read line
	do 
	 	apply_kconfig $line
	done < $1
}

build_initrd()
{
	(
		mkdir -p $INITRD
		mkdir -p $ROOTFS/usr
		cp -p $LINUX_SRC/scripts/gen_initramfs_list.sh $INITRD
		cp -p $LINUX_SRC/usr/gen_init_cpio $INITRD/usr
		cd $INITRD
		sudo sh gen_initramfs_list.sh -o $FLASH/boot/initrd.img-$LINUX_VER-$LINUX_MACH $ROOTFS
		echo "$FLASH/boot/initrd.img-$LINUX_VER-$LINUX_MACH ready."
	)
}

copy_images()
{
	if [ "x$DRYRUN" != "xyes" -a "x$BUILDIMGS" = "xyes" ]; then
		if [ -f $KERNELIMG ]; then
			sudo cp -f $KERNELIMG $FLASH/boot/vmlinuz-$LINUX_VER-$LINUX_MACH
			sudo cp -f $KERNELCFG $FLASH/boot/config-$LINUX_VER-$LINUX_MACH
			echo "$FLASH/boot/vmlinuz-$LINUX_VER-$LINUX_MACH ready."
			echo "$FLASH/boot/config-$LINUX_VER-$LINUX_MACH ready."
			#build_initrd
		fi
	fi
}

build_all_config()
{
	if [ "x$BUILDFAIL" = "xyes" ]; then
		return 1
	fi

	# Test builds
	echo "=============================="
	echo "Testing all config $1"
	echo "=============================="
	(
		echo "Entering $LINUX_SRC"
		cd $LINUX_SRC
		make ARCH=$BUILD_ARCH ${1}config
		build_kernel $1
	)
}

build_def_config()
{
	if [ "x$BUILDFAIL" = "xyes" ]; then
		return 1
	fi

	# Default builds
	echo "=============================="
	echo "Testing default config linux-$LINUX_VER-$LINUX_MACH"
	echo "=============================="
	(
		echo "Entering $LINUX_SRC"
		cd $LINUX_SRC
		copy_configs
		build_kernel default
	)
}

build_cfg_config()
{
	if [ "x$BUILDFAIL" = "xyes" ]; then
		return 1
	fi

	# Test builds
	echo "=============================="
	echo "Testing special config $1"
	echo "=============================="
	(
		echo "Entering $LINUX_SRC"
		cd $LINUX_SRC
		copy_configs
		apply_kconfig_file $SCRIPT/defconfig/$1
		build_kernel $1
	)
}

peek_head()
{
	(
		cd $LINUX_SRC
		git log -1 -c HEAD --format=%H | cut -c1-8
	)
}

merge_patch()
{
	(
		cd $LINUX_SRC
		echo "Merging $1 after $COMMIT..."
		rm -f patches/${1}-$LINUX_VER-$LINUX_MACH
		rm -f 0001*.patch
		git am patches/$1 >/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "Merge $1 failure..."
			git am --abort >/dev/null 2>&1
			exit 1
		fi
	)
}

sign_off_patch()
{
	(
		cd $LINUX_SRC
		if [ "x$BUILDFAIL" = "xno" ]; then
			echo "Signing off $1..."
			git format-patch -s -1 1>/dev/null 2>&1
			file=`ls 0001*.patch`
			mv -f $file patches/${1}-$LINUX_VER-$LINUX_MACH
		fi
		echo "Resetting to $COMMIT..."
		git reset $COMMIT --hard >/dev/null 2>&1
		if [ "x$BUILDFAIL" = "xyes" ]; then
			exit 1
		fi
	)
}

check_rebuild_arch()
{
	arch=$LINUX_ARCH
	if [ "x$LINUX_SUBARCH" != "x" ]; then
		arch=$LINUX_SUBARCH
	fi
	if [ "x$FORCEREBUILD" = "xyes" ]; then
		REBUILD="yes"
	elif [ "x$FORCEREBUILD" = "xno" ]; then
		REBUILD="no"
	elif [ "x$arch" != "x$BUILD_ARCH" ]; then
		REBUILD="yes"
	fi
	BUILD_ARCH=$arch
}

SCRIPT=`(cd \`dirname $0\`; pwd)`
FLASH=$SCRIPT/disk
ROOTFS=$SCRIPT/rootfs
INITRD=$SCRIPT/initrd
STATUS=$SCRIPT/status
SCFGTESTS=
BUILDCFGS=
SOBJTESTS=
MAKEFLAGS=
BUILDFAIL=no
QUILTPATCH=
CHECKER=0
WARNING=0

while getopts "b:c:dimno:p:q:r:svwy" opt
do
	case $opt in
	y) BUILDALLYES="yes";;
	n) BUILDALLNO="yes";;
	m) BUILDALLMOD="yes";;
	b) if [ -f $SCRIPT/defconfig/$OPTARG ]; then
		BUILDCFGS="$BUILDCFGS $OPTARG"
	   else
		"$OPTARG is not accessible."
		usage
	   fi;;
	c) if [ -f $SCRIPT/defconfig/$OPTARG ]; then
		SCFGTESTS="$SCFGTESTS $OPTARG"
	   else
		"$OPTARG is not accessible."
		usage
	   fi;;
	o) if [ -f $SCRIPT/defconfig/$OPTARG ]; then
		load_objects $SCRIPT/defconfig/$OPTARG
	   else
		"$OPTARG is not accessible."
		usage
	   fi;;
	q) QUILTPATCH=$OPTARG;;
	s) if [ $CHECKER -lt 2 ]; then
		CHECKER=`expr $CHECKER + 1`
	   fi;;
	p) MAKEFLAGS="$MAKEFLAGS -j$OPTARG";;
	w) if [ $WARNING -lt 3 ]; then
		WARNING=`expr $WARNING + 1`
	   fi;;
	r) FORCEREBUILD=$OPTARG;;
	d) DRYRUN="yes";;
	i) BUILDIMGS="yes";;
	v) if [ "x$VERBOSE" = "x" ]; then
		VERBOSE=0
	   elif [ $VERBOSE -lt 2 ]; then
		VERBOSE=`expr $VERBOSE + 1`
	   fi;;
	?) echo "Invalid argument $opt"
	   usage;;
	esac
done

if [ "x$BUILDCFGS" = "x" ]; then
	usage
fi

if [ $CHECKER -gt 0 ]; then
	MAKEFLAGS="$MAKEFLAGS C=$CHECKER CF=\"-D__CHECK_ENDIAN__\""
fi
if [ $WARNING -gt 0 ]; then
	MAKEFLAGS="$MAKEFLAGS W=$WARNING"
fi
if [ "x$VERBOSE" != "x" ]; then
	if [ $VERBOSE -gt 0 ]; then
		MAKEFLAGS="$MAKEFLAGS V=$VERBOSE"
	fi
fi

echo $MAKEFLAGS

for cfg in $BUILDCFGS; do
	. $SCRIPT/defconfig/$cfg

	check_rebuild_arch
	CUSTOM_DSDT=$SCRIPT/defconfig/dsdt.hex-$LINUX_MACH
	LINUX_SRC=$SCRIPT/workspace/linux-$LINUX_VER
	LINUX_CFG=$SCRIPT/defconfig/linux-config-$LINUX_VER-$LINUX_MACH
	KERNELIMG=$LINUX_SRC/arch/$LINUX_ARCH/boot/bzImage
	KERNELCFG=$LINUX_SRC/.config
	KERNELDSDT=$LINUX_SRC/include/acpi/dsdt.hex
	MODCONFIG=$LINUX_SRC/scripts/config
	COMMIT=`peek_head`

	if [ "x$QUILTPATCH" != "x" ]; then
		merge_patch $QUILTPATCH || exit 1
	fi

	build_def_config || exit 1

	copy_images

	if [ "x$BUILDALLYES" = "xyes" ]; then
		build_all_config allyes || exit 1
	fi
	if [ "x$BUILDALLNO" = "xyes" ]; then
		build_all_config allno || exit 1
	fi
	if [ "x$BUILDALLMOD" = "xyes" ]; then
		build_all_config allmod || exit 1
	fi

	for cfg in $SCFGTESTS; do 
		build_cfg_config $cfg || exit 1
	done

	if [ "x$QUILTPATCH" != "x" ]; then
		sign_off_patch $QUILTPATCH || exit 1
	fi
done

