#!/bin/sh
set -e

arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
  printf 'Error: unsupported architecture (%s). This script supports x86_64 only. skipping.\n' "$arch" >&2
  exit 0
fi

# obs-multi-rtmp
echo "Installing obs-multi-rtmp..."
#PACKAGE_URL=`get-github-download-url sorayuki obs-multi-rtmp 'obs-multi-rtmp-.*x86_64-linux-gnu\.deb$'`
PACKAGE_URL='https://github.com/sorayuki/obs-multi-rtmp/releases/download/0.7.3/obs-multi-rtmp-0.7.3.0-x86_64-linux-gnu.deb'
echo "Downloading '$PACKAGE_URL'..."
download "$PACKAGE_URL" > /tmp/obs-multi-rtmp.deb
deb2targz /tmp/obs-multi-rtmp.deb
mkdir /tmp/obs-multi-rtmp
tar xvf /tmp/obs-multi-rtmp.tar.gz -C /tmp/obs-multi-rtmp
mv /tmp/obs-multi-rtmp/usr/lib/x86_64-linux-gnu/obs-plugins/*.so /usr/lib64/obs-plugins/
mv /tmp/obs-multi-rtmp/usr/share/obs/obs-plugins/* /usr/share/obs/obs-plugins/

# advanced-scene-switcher
echo "Installing advanced-scene-switcher..."
mkdir /tmp/advanced-scene-switcher
download `get-github-download-url WarmUpTill SceneSwitcher 'advanced-scene-switcher-.*-x86_64-linux-gnu.tar.xz'` | tar Jxvf - -C /tmp/advanced-scene-switcher
mv /tmp/advanced-scene-switcher/share/obs/obs-plugins/advanced-scene-switcher /usr/share/obs/obs-plugins/
mv /tmp/advanced-scene-switcher/lib/x86_64-linux-gnu/obs-plugins/* /usr/lib64/obs-plugins/

# waveform
echo "Installing waveform..."
download `get-github-download-url phandasm waveform '.*_Ubuntu_x86_64\.deb$'` > /tmp/waveform.deb
deb2targz /tmp/waveform.deb
mkdir /tmp/waveform
tar xvf /tmp/waveform.tar.gz -C /tmp/waveform
mv /tmp/waveform/usr/lib/x86_64-linux-gnu/obs-plugins/*.so /usr/lib64/obs-plugins/
mv /tmp/waveform/usr/share/obs/obs-plugins/* /usr/share/obs/obs-plugins/

# distroav
echo "Installing distroav..."
download `get-github-download-url DistroAV DistroAV '.*-x86_64-linux-gnu\.deb$'` > /tmp/distroav.deb
deb2targz /tmp/distroav.deb
mkdir /tmp/distroav
tar xvf /tmp/distroav.tar.gz -C /tmp/distroav
mv /tmp/distroav/usr/lib/x86_64-linux-gnu/obs-plugins/*.so /usr/lib64/obs-plugins/
mv /tmp/distroav/usr/share/obs/obs-plugins/* /usr/share/obs/obs-plugins/
