#!/bin/sh
# ref: srs/files/build.d/srs-ipv6.sh
# 公式 media-video/srs 同梱の /etc/srs/srs.conf は各 listen を IPv4 のみ
# ("listen <port>;") で待ち受ける。Linux の dual-stack で IPv6/IPv4 両方を
# 受けられるよう、TCP リスナーの listen を "listen [::]:<port>;" に書き換える。
#
# 対象: RTMP(1935) と http_api(1985)。
# 除外: srt_server(10080)。SRS の srt_server.listen はポート番号(整数)のみを
#       受け付ける仕様で、"[::]:10080" を与えると整数パースに失敗し port 0 →
#       ランダムな ephemeral ポートを IPv4 で bind してしまう。よって SRT は
#       IPv4 の "listen 10080;" のまま残す (この listen 指定では IPv6 非対応)。
set -e

CONF=/etc/srs/srs.conf
[ -f "$CONF" ] || exit 0

sed -i -E 's/^([[:space:]]*)listen([[:space:]]+)(1935|1985);/\1listen\2[::]:\3;/' "$CONF"
