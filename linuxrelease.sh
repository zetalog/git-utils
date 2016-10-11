#!/bin/sh
#
# Copyright (C) 2014-2015 ZETALOG PERSONAL
# Author: Lv Zheng <zetalog@gmail.com>
#
# Typical build configuration file contents (basic kconfig configs):
# ######################
# # LINUX_VER=acpica   #
# # LINUX_ARCH=x86     #
# # LINUX_SUBARCH=i386 #
# # LINUX_MACH=z530    #
# # LINUX_TOOLS=acpi   #
# ######################
# It should locate at (-b file):
# $HOME/defconfig/file
# Then:
# The kconfig file should locate at:
# $HOME/defconfig/linux-config-acpica-z530
# The customized DSDT should locate at:
# $HOME/defconfig/dsdt.hex-z530
# The Linux kernel source should locate at:
# $HOME/workspace/linux-acpica
# And, the following kernel tools will be built:
# acpi
#
# Typical special config test file contents (extra kconfig configs):
# #################
# # CONFIG_ACPI=n #
# #################
# It should locate at (-c file):
# $HOME/defconfig/file
# This allows additional build test to be performed by disabling ACPI.
#
# Typical special object test file contents (extra targets):
# ######################################
# # arch/x86/pci/mmconfig-shared.o     #
# # drivers/firmware/iscsi_ibft_find.o #
# # drivers/sfi/sfi_acpi.o             #
# ######################################
# It should locate at (-o file):
# $HOME/defconfig/file
# This allows additional make targets to be performed.

usage()
{
	echo "Usage: `basename $0` [-b build] [-c config] [-o object] [-p thread] [-q patch] [-r rebuild] [-isw] [-kdynm] [-ev]"
	echo "Where:"
	echo "  -y: build allyesconfig"
	echo "  -n: build allnoconfig"
	echo "  -m: build allmodconfig"
	echo "  -b: specify basic kconfig configs"
	echo "  -d: build basic kconfig configs"
	echo "  -c: specifiy extra kconfig configs"
	echo "      to build basic+extra kconfig configs"
	echo "  -o: specify extra targets (usually single object file)"
	echo "      to perform make on these targets"
	echo "  -i: prepare disk images"
	echo "  -k: apply kconfig configs without building kernels"
	echo ""
	echo "  -p: specify parallel build threads"
	echo "  -q: test and sign quilt patch"
	echo "  -r: enable rebuilding"
	echo "      no: never enable rebuilding"
	echo "      yes: always enable rebuilding"
	echo ""
	echo "  -s: increase checker level (max 2, C=1, C=2)"
	echo "  -w: increase warning level (max 3, W=1, W=2, W=3)"
	echo ""
	echo "  -e: no execution (dry run)"
	echo "  -v: increase verbose level (max 3, V=0, V=1, V=2)"
	exit 0
}

log_name()
{
	if [ "x$QUILTPATCH" = "x" ]; then
		echo $LINUX_VER-$LINUX_MACH-$LINUX_BLD.log
	else
		echo $LINUX_VER-$LINUX_MACH-$LINUX_BLD-$QUILTPATCH.log
	fi
}

log_init()
{
	LINUX_BLD=$1
	log=`log_name`

	echo > $log
}

log()
{
	log=`log_name`

	echo $@ | tee -a $log
}

tlog_name()
{
	echo ../$LINUX_VER-$LINUX_MACH-tools.log
}

tlog_init()
{
	tlog=`tlog_name`

	echo $tlog
	echo > $tlog
}

tlog()
{
	tlog=`tlog_name`

	echo $@ | tee -a $tlog
}

tlog_exit()
{
	tlog=`tlog_name`

	echo $tlog
	echo >> $tlog
}

load_objects()
{
	objs=`cat $1`
	SOBJTESTS="$SOBJTESTS $objs"
}

modify_kconfig()
{
	if [ "x$1" =  "x--disable" ]; then
		log " Disabling $2"
	else
		log " Enabling $2"
	fi
	$MODCONFIG $@
	make oldconfig 1>/dev/null 2>&1
	cfg=`cat ./.config | grep ^CONFIG_$2=`
	if [ "x$1" =  "x--disable" ]; then
		if [ "x$cfg" != "x" ]; then
			log "Failed to disable $2, please check dependencies."
			exit 1
		fi
	else
		if [ "x$cfg" = "x" ]; then
			log "Failed to enable $2, please check dependencies."
			exit 1
		fi
	fi
}

copy_configs()
{
	log "Copying $LINUX_CFG"
	if [ "x$DRYRUN" != "xyes" ]; then
		rm -f $KERNELIMG
		cp -f $LINUX_CFG $KERNELCFG
	fi
	if [ "x$CUSTOM_DSDT" != "x" ]; then
		if [ -f $CUSTOM_DSDT ]; then
			log "Copying $CUSTOM_DSDT"
			if [ "x$DRYRUN" != "xyes" ]; then
				cp -f $CUSTOM_DSDT $KERNELDSDT
				apply_kconfig CONFIG_STANDALONE=n
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
	log=`log_name`

	for obj in $SOBJTESTS; do
		log "=============================="
		log "Testing special object $obj"
		log "=============================="
		if [ "x$DRYRUN" != "xyes" ]; then
			rm -f $obj
			log "=========="
			log "Testing $obj"
			log "=========="
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
	tlog=`tlog_name`
	t=$1
	d=$2

	tlog "=========="
	tlog "Building tools-$t"
	tlog "=========="
	if [ "x$DRYRUN" != "xyes" ]; then
		if [ "x$REBUILD" = "xyes" ]; then
			make ${t}_clean
		fi
		if [ "x$VERBOSE" != "x" ]; then
			make DEBUG=$d $MAKEFLAGS $t 2>&1 | tee -a $tlog
		else
			make DEBUG=$d $MAKEFLAGS $t 2>&1 >>$tlog
		fi
	else
		echo make DEBUG=$d $MAKEFLAGS $t 2>&1
	fi

	tlog "=========="
	tlog "Installing tools-$t to $ROOTFS"
	tlog "=========="
	if [ "x$DRYRUN" != "xyes" ]; then
		if [ "x$NOKERNELBUILD" != "xyes" ]; then
			if [ "x$VERBOSE" != "x" ]; then
				make ${t}_uninstall DESTDIR=$ROOTFS 2>&1 | tee -a $tlog
				make ${t}_install DESTDIR=$ROOTFS 2>&1 | tee -a $tlog
			else
				make ${t}_uninstall DESTDIR=$ROOTFS >>$tlog
				make ${t}_install DESTDIR=$ROOTFS >>$tlog
			fi
		fi
	else
		echo make ${t}_uninstall DESTDIR=$ROOTFS
		echo make ${t}_install DESTDIR=$ROOTFS
	fi
}

build_kernel()
{
	log=`log_name`

	save_status $1

	if [ "x$1" = "xdefault" ]; then
	(
		cd tools
		tlog_init
		for t in $LINUX_TOOLS; do
			build_tool $t false
			build_tool $t true
		done
		tlog_exit
	)
	fi

	if [ "x$DRYRUN" != "xyes" ]; then
		log "=========="
		log "Building kernel"
		log "=========="
		make ARCH=$BUILD_ARCH oldconfig
		apply_kconfig CONFIG_STAGING=n

		if [ "x$NOKERNELBUILD" != "xyes" ]; then
			if [ "x$REBUILD" = "xyes" ]; then
				make ARCH=$BUILD_ARCH clean
			fi
			if [ "x$VERBOSE" != "x" ]; then
				make $MAKEFLAGS ARCH=$BUILD_ARCH 2>&1 | tee -a $log
			else
				make $MAKEFLAGS ARCH=$BUILD_ARCH 2>&1 >>$log
			fi
		fi

		log "=========="
		log "Installing kernel to $ROOTFS"
		log "=========="
		if [ "x$NOKERNELBUILD" != "xyes" ]; then
			if [ "x$VERBOSE" != "x" ]; then
				make ARCH=$BUILD_ARCH INSTALL_MOD_PATH=$ROOTFS modules_install 2>&1 | tee -a $log
				make ARCH=$BUILD_ARCH INSTALL_PATH=$ROOTFS install 2>&1 | tee -a $log
			else
				make ARCH=$BUILD_ARCH INSTALL_MOD_PATH=$ROOTFS modules_install 2>&1 >>$log
				make ARCH=$BUILD_ARCH INSTALL_PATH=$ROOTFS install 2>&1 >>$log
			fi
		fi

		if [ -f $KERNELIMG ]; then
			log "Building linux-$LINUX_VER-$LINUX_MACH success."
		else
			BUILDFAIL=yes
			log "Building linux-$LINUX_VER-$LINUX_MACH failure."
		fi
	else
		echo "=========="
		echo "Building kernel"
		echo "=========="
		echo make ARCH=$BUILD_ARCH oldconfig
		echo CONFIG_STAGING=n
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
		log "$FLASH/boot/initrd.img-$LINUX_VER-$LINUX_MACH ready."
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
	echo "Testing all config $LINUX_BLD"
	echo "=============================="
	(
		echo "Entering $LINUX_SRC"
		cd $LINUX_SRC
		log_init $1
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
		log_init default
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
		log_init $1
		copy_configs
		apply_kconfig_file $CFGDIR/$1
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
HOME=`(cd ~; pwd)`

CFGDIR=$HOME/defconfig
FLASH=$HOME/disk
ROOTFS=$HOME/rootfs
INITRD=$HOME/initrd
STATUS=$HOME/status

SCFGTESTS=
BUILDCFGS=
SOBJTESTS=
MAKEFLAGS=
BUILDFAIL=no
QUILTPATCH=
CHECKER=0
WARNING=0

while getopts "b:c:deikmno:p:q:r:svwy" opt
do
	case $opt in
	d) BUILDDEFAULT="yes";;
	y) BUILDALLYES="yes";;
	n) BUILDALLNO="yes";;
	m) BUILDALLMOD="yes";;
	i) BUILDDEFAULT="yes"
	   BUILDIMGS="yes";;
	k) NOKERNELBUILD="yes";;
	b) if [ -f $CFGDIR/$OPTARG ]; then
		BUILDCFGS="$BUILDCFGS $OPTARG"
	   else
		"$OPTARG is not accessible."
		usage
	   fi;;
	c) if [ -f $CFGDIR/$OPTARG ]; then
		SCFGTESTS="$SCFGTESTS $OPTARG"
	   else
		"$OPTARG is not accessible."
		usage
	   fi;;
	o) if [ -f $CFGDIR/$OPTARG ]; then
		load_objects $CFGDIR/$OPTARG
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
	e) DRYRUN="yes";;
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
	. $CFGDIR/$cfg

	check_rebuild_arch
	CUSTOM_DSDT=$CFGDIR/dsdt.hex-$LINUX_MACH
	LINUX_SRC=$HOME/workspace/linux-$LINUX_VER
	LINUX_CFG=$CFGDIR/linux-config-$LINUX_VER-$LINUX_MACH
	KERNELIMG=$LINUX_SRC/arch/$LINUX_ARCH/boot/bzImage
	KERNELCFG=$LINUX_SRC/.config
	KERNELDSDT=$LINUX_SRC/include/acpi/dsdt.hex
	MODCONFIG=$LINUX_SRC/scripts/config
	COMMIT=`peek_head`

	if [ "x$QUILTPATCH" != "x" ]; then
		merge_patch $QUILTPATCH || exit 1
	fi

	if [ "x$BUILDDEFAULT" = "xyes" ]; then
		build_def_config || exit 1
		copy_images
	fi
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

