#!/bin/bash
set -e
set -o pipefail

function calltracer () {
	echo 'Last file/last line:'
	caller
}
trap 'calltracer' ERR

