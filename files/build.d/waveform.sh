#!/bin/sh
# ref: obs-plugins/files/build.d/waveform.sh
set -e

arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
  printf 'Unsupported architecture (%s). Skipping waveform.\n' "$arch" >&2
  exit 0
fi

echo "Installing waveform..."
download $(get-github-download-url phandasm waveform '.*_Ubuntu_x86_64\.deb$') > /tmp/waveform.deb
deb2targz /tmp/waveform.deb
mkdir /tmp/waveform
tar xvf /tmp/waveform.tar.gz -C /tmp/waveform
mv /tmp/waveform/usr/lib/x86_64-linux-gnu/obs-plugins/*.so /usr/lib64/obs-plugins/
mv /tmp/waveform/usr/share/obs/obs-plugins/* /usr/share/obs/obs-plugins/
