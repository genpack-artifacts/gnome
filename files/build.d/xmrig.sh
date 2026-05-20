#!/bin/sh
set -e

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_STR="x64"
else
    echo "Unsupported architecture: $ARCH. Skipping xmrig installation."
    exit 0
fi

echo 'Downloading xmrig...'
download $(get-github-download-url xmrig xmrig "xmrig-.*-jammy-${ARCH_STR}\.tar\.gz$") | tar zxvf - -C /tmp
mv /tmp/xmrig-*/xmrig /usr/bin/
