#!/bin/sh
# ref: obs-plugins/files/build.d/waveform.sh
# OBS 33.0 からの新ロケーション (obs-modules/plugins) へ設置する。
# 旧ロケーション (/usr/lib64/obs-plugins) でも 34.0 までは読めるが Plugin Manager で
# Legacy 扱いになるため使わない。
set -e

arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
  printf 'Unsupported architecture (%s). Skipping waveform.\n' "$arch" >&2
  exit 0
fi

plugin_module_dir=/usr/lib64/obs-modules/plugins
plugin_data_dir=/usr/share/obs/obs-modules/plugins

echo "Installing waveform..."
download $(get-github-download-url phandasm waveform '.*_Ubuntu_x86_64\.deb$') > /tmp/waveform.deb
deb2targz /tmp/waveform.deb
mkdir -p /tmp/waveform
tar xf /tmp/waveform.tar.gz -C /tmp/waveform
mkdir -p "$plugin_module_dir" "$plugin_data_dir"
# 配布 deb の libdir は distro により multiarch 化されているため find で拾う
find /tmp/waveform/usr/lib -path '*/obs-plugins/*' -name '*.so' -exec mv -t "$plugin_module_dir" {} +
mv /tmp/waveform/usr/share/obs/obs-plugins/* "$plugin_data_dir"/
