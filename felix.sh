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
	echo "	--int=INT                                          default value: 10"
	echo "	--float=FLOAT                                      default value: 20"
	echo "	--help                                             this help"
	echo "	--debug                                            Enables debug mode (set -x)"
	exit $1
}
export int=10
export float=20
for i in $@; do
	case $i in
		--int=*)
			int="${i#*=}"
			re='^[+-]?[0-9]+$'
			if ! [[ $int =~ $re ]] ; then
				echo "error: Not a INT: $i" >&2
				help 1
			fi
			shift
			;;
		--float=*)
			float="${i#*=}"
			re='^[+-]?[0-9]+([.][0-9]+)?$'
			if ! [[ $float =~ $re ]] ; then
				echo "error: Not a FLOAT: $i" >&2
				help 1
			fi
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
