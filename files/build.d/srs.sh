#!/bin/sh
# ref: srs/files/build.d/srs.sh
set -e

# get-github-download-url は GitHub の "Latest release" を取得する。
# 特定バージョンに固定したい場合は以下のようにURLを直接指定する:
#   SRS_URL="https://github.com/ossrs/srs/releases/download/v6.0-r0/srs-server-6.0-r0.tar.gz"
SRS_URL=$(get-github-download-url ossrs srs 'srs-server-.*\.tar\.gz$')

download $SRS_URL | tar zxvf - -C /tmp
cd /tmp/srs-server-*/trunk
# remove amfenc stuffs from libavcodec build
grep -v amfenc 3rdparty/ffmpeg-4-fit/libavcodec/Makefile > libavcodec-makefile
mv libavcodec-makefile 3rdparty/ffmpeg-4-fit/libavcodec/Makefile
# no use system ffmpeg as SRS is not compatible with ffmpeg 7
./configure --generic-linux=on --sanitizer=off --sys-ssl=on --sys-srtp=on --sys-srt=on --sys-ffmpeg=off
make
cp -a objs/srs /usr/bin/
mkdir -p /var/lib/srs /var/www/srs
chown nobody:nobody /var/lib/srs /var/www/srs
cp packaging/redhat/srs.service /usr/lib/systemd/system/
sed -i 's/\/var\/lib\/srs\/srs\.pid/\/run\/srs\/srs.pid/' /usr/lib/systemd/system/srs.service

echo 'd /run/srs 0755 nobody nobody -' > /usr/lib/tmpfiles.d/srs.conf
mkdir -p /etc/srs
cat <<EOF > /etc/srs/srs.conf
listen [::]:1935;
srs_log_tank console;
srs_log_level info;
pid /run/srs/srs.pid;

vhost __defaultVhost__ {
}
EOF
