#!/bin/sh
# ref: opencode/files/build.d/opencode.sh
set -e

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        TARGET=x64
        ;;
    aarch64)
        TARGET=arm64
        ;;
    *)
        echo "Unsupported architecture: $ARCH. Skipping opencode installation."
        exit 0
        ;;
esac

# v2系の最新安定版を追う。
# GitHub の /releases/latest は v2 公開後も v1 系に固定されているため、
# /releases を巡回して draft/prerelease でない v2.* タグの最新を取る。
# JSON の解析には genpack/base で保証されている python を使う。
version=""
page=1
while [ "$page" -le 10 ]; do
    parsed=$(download "https://api.github.com/repos/anomalyco/opencode/releases?per_page=100&page=${page}" | python -c '
import json, re, sys
releases = json.load(sys.stdin)
rel = next((r for r in releases
            if not r.get("draft") and not r.get("prerelease")
            and re.match(r"^v2\.\d", r.get("tag_name") or "")), None)
print(rel["tag_name"] if rel else "")
print(len(releases) if isinstance(releases, list) else 0)
')
    found=$(printf '%s\n' "$parsed" | sed -n '1p')
    count=$(printf '%s\n' "$parsed" | sed -n '2p')
    if [ -n "$found" ]; then
        version=${found#v}
        break
    fi
    if [ "${count:-0}" -lt 100 ]; then
        break
    fi
    page=$((page + 1))
done
if [ -z "$version" ]; then
    echo "could not determine latest v2 release of anomalyco/opencode" >&2
    exit 1
fi

echo "Downloading opencode v${version} (linux-${TARGET})..."
download "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-${TARGET}.tar.gz" > /tmp/opencode.tar.gz
tar zxf /tmp/opencode.tar.gz -C /usr/bin opencode
rm -f /tmp/opencode.tar.gz
chmod 755 /usr/bin/opencode
