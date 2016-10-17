#!/bin/sh

usage()
{
	echo "Usage:"
	echo "`basename $0` [-b branch] [-m] [-n number] [-s start] [-t track] <repository>"
	echo "Where:"
	echo "  -b:	checkout a specified local branch"
	echo "     	(default local branch is quilt)"
	echo "  -d:	dry run"
	echo "  -m:	merge patches in the quilt repository"
	echo "  -n:	number of the patches to merge"
	echo "  -s:	start of the patches to merge, default is 0"
	echo "  -t:	checkout a branch to track the specified remote branch"
	echo "  	Example: Use \"-t linux-next\" to track origin/linux-next."
	echo "  	Note: The local-branch default name will be same as the remote-branch"
	echo "  	      name unless overwritten by further -b options."
	exit -1
}

GITTRACK=
MERGESTART=0

while getopts "b:dmn:s:t:" opt
do
	case $opt in
	b) GITBRANCH=$OPTARG;;
	d) DRYRUN=yes;;
	m) QUILTMERGE=yes;;
	n) MERGECOUNT=$OPTARG;;
	s) MERGESTART=$OPTARG;;
	t) GITTRACK="--track origin/$OPTARG"
	   GITBRANCH=$OPTARG;;
	?) echo "Invalid argument $opt"
	   usage;;
	esac
done
shift $(($OPTIND - 1))

if [ "x$1" = "x" ]; then
	usage
fi

REPO=`(cd $1; pwd)`

reset_repo()
{
	repo=$1
	(
		cd $repo

		quilt applied 1>/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Removing quilt patches..."
			if [ "x$DRYRUN" = "xyes" ]; then
				echo quilt pop -a
			else
				quilt pop -a || return 1
			fi
		fi

		git diff --exit-code 1>/dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "Resetting git repository..."
			if [ "x$DRYRUN" = "xyes" ]; then
				echo git reset --hard
			else
				git reset --hard || return 1
			fi
		fi
	)
}

branch_repo()
{
	repo=$1
	(
		cd $repo
		echo "Checking out the master branch..."
		if [ "x$DRYRUN" = "xyes" ]; then
			echo git checkout master
		else
			git checkout master
		fi
		echo "Deleting the $GITBRANCH branch..."
		if [ "x$DRYRUN" = "xyes" ]; then
			echo git branch -D $GITBRANCH
		else
			git branch -D $GITBRANCH
		fi
		echo "Checking out the $GITBRANCH branch..."
		if [ "x$DRYRUN" = "xyes" ]; then
			echo git checkout -b $GITBRANCH $GITTRACK
		else
			git checkout -b $GITBRANCH $GITTRACK
		fi
	)
}

merge_patch()
{
	repo=$1
	name=$2
	if [ -f $repo/patches/$name ]; then
		patch=patches/$name
	elif [ -f $repo/$name ]; then
		patch=$name
	else
		echo "No such patch: $name."
		return 1
	fi
	(
		cd $repo
		echo "Merging $patch..."
		if [ "x$DRYRUN" = "xyes" ]; then
			echo git am $patch
		else
			git am $patch
		fi
	)
	return 0
}

echo "Working on $REPO..."

reset_repo $REPO || exit 1

if [ "x$GITBRANCH" != "x" ]; then
	branch_repo $REPO || exit 1
fi

if [ "x$QUILTMERGE" = "xyes" ]; then
	count=0
	index=0
	series=`quilt series`
	for name in $series; do
		if [ "x$MERGESTART" = "x$index" ]; then
			merge_patch $REPO $name
			if [ $? -eq 0 ]; then
				count=`expr $count + 1`
			else
				echo "Failed to merge $name."
				break
			fi
			MERGESTART=`expr $MERGESTART + 1`
		fi
		index=`expr $index + 1`
		if [ "x$count" = "x$MERGECOUNT" ]; then
			break
		fi
	done
	echo "$count patches are merged into $REPO."
fi

