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
	echo "	--colorsource"
	echo "	--largeimage"
	echo "	--help                                             this help"
	echo "	--debug                                            Enables debug mode (set -x)"
	exit $1
}
export colorsource
export largeimage
for i in $@; do
	case $i in
		--colorsource=*)
			colorsource="${i#*=}"
			shift
			;;
		--largeimage=*)
			largeimage="${i#*=}"

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

function hsl_merger {
	source=$1
	large=$2

	if [[ -e $source ]]; then
		if [[ -e $large ]]; then
			echo "OK"
		else
			echo "Source $large cannot be found"
		fi
	else
		echo "Source $source cannot be found"
	fi
}

hsl_merger $colorsource $largeimage
