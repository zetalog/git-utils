#!/bin/sh

usage()
{
	echo "Usage:"
	echo "`basename $0` [-dp] <repository> <patches>"
	echo "Where:"
	echo "  -d:	dry run"
	echo "  -f:	force 'quilt pop' and 'git reset'"
	exit -1
}

while getopts "df" opt
do
	case $opt in
	d) DRYRUN=yes;;
	f) FORCE=yes;;
	?) echo "Invalid argument $opt"
	   usage;;
	esac
done
shift $(($OPTIND - 1))

if [ "x$1" = "x" ]; then
	usage
fi
if [ "x$2" = "x" ]; then
	usage
fi

REPO=`(cd $1; pwd)`
PATCHES=~/defconfig/patches/linux/$2

repo_is_init()
{
	repo=$1

	if [ ! -e $repo/patches ]; then
		return 1;
	fi

	return 0
}

exit_repo()
{
	repo_is_init $1 || return 0

	repo=$1
	(
		cd $repo

		quilt applied 1>/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Removing quilt patches..."
			if [ "x$DRYRUN" = "xyes" ]; then
				echo quilt pop -a
			else
				msg=`quilt pop -a`
				if [ $? -ne 0 ]; then
					if [ "x$FORCE" = "xyes" ]; then
						quilt pop -af
					else
						echo "Please check unmreged quilt differences."
						return 1
					fi
				fi
			fi
		fi

		git diff --exit-code 1>/dev/null 2>&1
		if [ $? -ne 0 ]; then
			if [ "x$FORCE" = "xyes" ]; then
				echo "Resetting git repository..."
				if [ "x$DRYRUN" = "xyes" ]; then
					echo git reset --hard
				else
					git reset --hard 1>/dev/null 2>&1 || return 1
				fi
			else
				echo "Please check unmreged git differences."
				return 1
			fi
		fi

		echo "Unlinking quilt repository..."
		if [ "x$DRYRUN" = "xyes" ]; then
			echo rm -f $repo/patches
		else
			rm -f $repo/patches
		fi
	)
}

init_repo()
{
	repo_is_init $1 && return 0

	repo=$1
	patches=$2
	(
		cd $repo

		echo "Linking quilt repository..."
		if [ "x$DRYRUN" = "xyes" ]; then
			echo ln -s $patches ./patches
		else
			ln -s $patches ./patches
		fi
	)
}

echo "Working on $REPO..."

exit_repo $REPO || exit 1
init_repo $REPO $PATCHES

