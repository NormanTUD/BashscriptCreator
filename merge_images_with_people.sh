#!/bin/bash
set -e
set -o pipefail
set -u

function calltracer () {
	echo 'Last file/last line:'
	caller
}
trap 'calltracer' ERR

function help () {
	echo "Possible options:"
	echo "	--faceimage"
	echo "	--backgroundimage"
	echo "	--help                                             this help"
	echo "	--debug                                            Enables debug mode (set -x)"
	exit $1
}
export faceimage
export backgroundimage
for i in $@; do
	case $i in
		--faceimage=*)
			faceimage="${i#*=}"
			shift
			;;
		--backgroundimage=*)
			backgroundimage="${i#*=}"
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
