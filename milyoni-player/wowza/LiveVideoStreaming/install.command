#!/bin/sh
echo "Installing LiveVideoStreaming..."
if [ -d /Library/WowzaMediaServer ]
then
	cd /Library/WowzaMediaServer/examples/LiveVideoStreaming
else
	cd /usr/local/WowzaMediaServer/examples/LiveVideoStreaming
fi

cp -R conf/* ../../conf/
mkdir ../../applications/live
mkdir ../../applications/rtplive
