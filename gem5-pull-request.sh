#!/bin/sh
#
# Usage: gem5-pull-request.sh <branch> <patch>...

SCRIPT=`(cd \`dirname $0\`; pwd)`
base_next=no
upstream=zetalog

usage()
{
	echo "Usage:"
	echo "`basename $0` [-r upstream] [-n] <branch> <patch>..."
	exit $1
}

fatal_usage()
{
	echo $1
	usage 1
}

while getopts "nr:" opt
do
	case $opt in
	r) upstream=$OPTARG;;
	n) base_next=yes;;
	?) echo "Invalid argument $opt"
	   fatal_usage;;
	esac
done
shift $(($OPTIND - 1))

if [ $# -lt 2 ]; then
	echo $#
	fatal_usage
fi

branch=$1
shift 1

# Sync upstream, note we need a clean base here
git fetch zetalog
git branch -D $branch
git branch $branch zetalog/master
git checkout $branch
if [ "x${base_next}" = "xyes" ]; then
	git merge zetalog/gem5-next
fi

# Merge patchset
for patch in "$@" do
	git am $patch
done
