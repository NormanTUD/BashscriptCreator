#!/bin/bash
set -e
set -o pipefail

function calltracer () {
	echo 'Last file/last line:'
	caller
}
trap 'calltracer' ERR

function help () {
	echo "Possible options:"
	echo "	--asdasd"
	echo "	--help                                             this help"
	echo "	--debug                                            Enables debug mode (set -x)"
	exit $1
}
export asdasd
for i in $@; do
	case $i in
		--asdasd=*)
			asdasd="${i#*=}"
			shift
			;;
		-h|--help)
			help 0
			;;
		--debug)
			set -x
			;;
		*)
			echo "Unknown parameter $i" >&2
			help 1
			;;
	esac
done
