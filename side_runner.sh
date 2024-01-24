#!/bin/bash

if [ ! -f lib/lib.sh ]
then
	echo "Error: lib/lib.sh not found!"
	echo "make sure you are in the root of the server repo"
	exit 1
fi

source lib/lib.sh

echo "*** server-plugin-disk ***"
echo "starting side runner with the following config:"
echo "max disk usage percentage=$CFG_PL_DISK_MAX_USAGE"

while true
do
	./lib/plugins/server-plugin-disk/lib/main.sh
	sleep 5m
done

