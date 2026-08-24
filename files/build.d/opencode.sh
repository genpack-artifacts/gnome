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

# 最新リリースを追う
URL=$(get-github-download-url anomalyco opencode "opencode-linux-${TARGET}\.tar\.gz$")

echo "Downloading opencode (linux-${TARGET})..."
download "$URL" > /tmp/opencode.tar.gz
tar zxf /tmp/opencode.tar.gz -C /usr/bin opencode
rm -f /tmp/opencode.tar.gz
chmod 755 /usr/bin/opencode
