#!/bin/sh
set -e

#SRS_DOWNLOAD_URL=`get-github-download-url ossrs srs '.*\.tar.gz$'`
SRS_DOWNLOAD_URL="https://github.com/ossrs/srs/releases/download/v6.0-b0/srs-server-6.0-b0.tar.gz"

download $SRS_DOWNLOAD_URL | tar zxvf - -C /tmp
cd /tmp/srs-server-*/trunk
# remove amfenc stuffs from libavcodec build
grep -v amfenc 3rdparty/ffmpeg-4-fit/libavcodec/Makefile > libavcodec-makefile
mv libavcodec-makefile 3rdparty/ffmpeg-4-fit/libavcodec/Makefile
# no use system ffmpeg as SRS is not compatible with ffmpeg 7
./configure --generic-linux=on --sanitizer=off --sys-ssl=on --sys-srtp=on --sys-srt=on --sys-ffmpeg=off
make
cp -a objs/srs /usr/bin/
mkdir /var/lib/srs /var/www/srs
chown nobody:nobody /var/lib/srs /var/www/srs
cp packaging/redhat/srs.service /usr/lib/systemd/system/
sed -i 's/\/var\/lib\/srs\/srs\.pid/\/run\/srs\/srs.pid/' /usr/lib/systemd/system/srs.service

echo 'd /run/srs 0755 nobody nobody -' > /usr/lib/tmpfiles.d/srs.conf
