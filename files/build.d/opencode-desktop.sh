#!/bin/sh
# ref: opencode/files/build.d/opencode-desktop.sh
set -e

# xdg-desktop-portal がインストールされていればGUIアーティファクトとみなして
# デスクトップ版(Electron)をインストールする。無ければ何もしない。
if ! require-installed sys-apps/xdg-desktop-portal; then
    echo "sys-apps/xdg-desktop-portal is not installed. Skipping opencode desktop."
    exit 0
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        TARGET=amd64
        ;;
    aarch64)
        TARGET=arm64
        ;;
    *)
        echo "Unsupported architecture: $ARCH. Skipping opencode desktop installation."
        exit 0
        ;;
esac

# 最新リリースを追う
URL=$(get-github-download-url anomalyco opencode "opencode-desktop-linux-${TARGET}\.deb$")

echo "Downloading opencode desktop (linux-${TARGET})..."
rm -rf /tmp/opencode-desktop
mkdir /tmp/opencode-desktop
cd /tmp/opencode-desktop
download "$URL" > opencode-desktop.deb
# .debはarアーカイブ。payload(data.tar.xz)をdeb内の構造のまま/に展開する
ar x opencode-desktop.deb
tar xJf data.tar.xz -C /
cd /
rm -rf /tmp/opencode-desktop

# SUIDが無いと非rootユーザーでElectronのサンドボックスが起動できない
chmod 4755 /opt/OpenCode/chrome-sandbox
