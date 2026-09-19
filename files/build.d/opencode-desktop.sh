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

# --- Patch app.asar: remove the Linux menu bar ---
#
# The release app keeps Electron's default menu on Linux: hidden, but toggled
# by the Alt key, which conflicts with Alt+~ IME switching. Patch createMenu()
# in out/main/index.js to drop the menu entirely on Linux; the in-window
# titlebar menu keeps providing all menu actions. The asar is rewritten in
# place (header offsets + SHA256 integrity recomputed).
# node is supplied by buildtime_packages (net-libs/nodejs).
if [ ! -f /opt/OpenCode/resources/app.asar ]; then
    echo "resources/app.asar missing in the release; release layout changed?" >&2
    exit 1
fi
if ! command -v node >/dev/null 2>&1; then
    echo "node is required to patch app.asar" >&2
    exit 1
fi
cat > asar-patch.js <<'EOF'
"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");

const target = process.argv[2];
if (!target) {
  console.error("usage: node asar-patch.js <path-to-app.asar>");
  process.exit(2);
}
const fail = (msg) => {
  console.error(`asar-patch: ${msg}`);
  process.exit(1);
};
const pad4 = (n) => (n + 3) & ~3;

const ORIGINAL = 'function createMenu(deps) {\n  if (process.platform !== "darwin") return;';
const PATCHED = [
  'function createMenu(deps) {',
  '  if (process.platform === "linux") {',
  '    Menu.setApplicationMenu(null);',
  '    return;',
  '  }',
  '  if (process.platform !== "darwin") return;',
].join("\n");

const fd = fs.openSync(target, "r");
const fileSize = fs.fstatSync(fd).size;
const prefix = Buffer.alloc(16);
fs.readSync(fd, prefix, 0, 16, 0);
const jsonLen = prefix.readUInt32LE(12);
if (
  prefix.readUInt32LE(0) !== 4 ||
  prefix.readUInt32LE(8) !== 4 + pad4(jsonLen) ||
  prefix.readUInt32LE(4) !== 8 + pad4(jsonLen)
)
  fail("unexpected asar header layout");
const headerJson = Buffer.alloc(jsonLen);
fs.readSync(fd, headerJson, 0, jsonLen, 16);
const header = JSON.parse(headerJson.toString("utf8"));
const blobStart = 8 + prefix.readUInt32LE(4);

const entries = [];
(function walk(node, prefixPath) {
  for (const [name, child] of Object.entries(node.files ?? {})) {
    if (child.files) walk(child, prefixPath + name + "/");
    else entries.push({ path: prefixPath + name, e: child });
  }
})(header, "");

const t = entries.find((f) => f.path === "out/main/index.js");
if (!t) fail("out/main/index.js not found in asar");
const orig = Buffer.alloc(t.e.size);
fs.readSync(fd, orig, 0, t.e.size, blobStart + parseInt(t.e.offset, 10));
const src = orig.toString("utf8");
if (src.includes("Menu.setApplicationMenu(null)")) {
  console.log(`asar-patch: ${target} already patched`);
  process.exit(0);
}
if (src.split(ORIGINAL).length !== 2)
  fail("createMenu() anchor not found exactly once; release layout changed?");
const patched = Buffer.from(src.replace(ORIGINAL, PATCHED), "utf8");

// verify blob layout is contiguous before touching anything
let off = 0;
for (const f of entries) {
  if (f.e.unpacked) continue;
  const o = parseInt(f.e.offset, 10);
  if (Number.isNaN(o) || o !== off)
    fail("asar blob layout is not contiguous; refusing to patch");
  off += f.e.size;
}

const sha256 = (b) => crypto.createHash("sha256").update(b).digest("hex");
t.e.size = patched.length;
t.e.integrity = { algorithm: "SHA256", hash: sha256(patched), blockSize: 4194304, blocks: [] };
for (let i = 0; i < patched.length; i += 4194304)
  t.e.integrity.blocks.push(sha256(patched.subarray(i, i + 4194304)));

// recompute blob offsets (shift after t)
off = 0;
for (const f of entries) {
  if (f.e.unpacked) continue;
  f.oldOff = parseInt(f.e.offset, 10);
  f.e.offset = String(off);
  off += f.e.size;
}
off = 0;
for (const f of entries) {
  if (f.e.unpacked) continue;
  f.e.offset = String(off);
  off += f.e.size;
}

const newHeaderJson = Buffer.from(JSON.stringify(header), "utf8");
const data = Buffer.alloc(fileSize);
fs.readSync(fd, data, 0, fileSize, 0);
fs.closeSync(fd);

const prefix2 = Buffer.alloc(16);
prefix2.writeUInt32LE(4, 0);
prefix2.writeUInt32LE(8 + pad4(newHeaderJson.length), 4);
prefix2.writeUInt32LE(4 + pad4(newHeaderJson.length), 8);
prefix2.writeUInt32LE(newHeaderJson.length, 12);
const parts = [
  prefix2,
  newHeaderJson,
  Buffer.alloc(pad4(newHeaderJson.length) - newHeaderJson.length),
];
for (const f of entries) {
  if (f.e.unpacked) continue;
  if (f === t) {
    parts.push(patched);
    continue;
  }
  parts.push(data.subarray(blobStart + f.oldOff, blobStart + f.oldOff + f.e.size));
}

const tmp = `${target}.tmp`;
fs.writeFileSync(tmp, Buffer.concat(parts));
fs.chmodSync(tmp, fs.statSync(target).mode & 0o7777);
fs.renameSync(tmp, target);

// verify the rewritten archive
const vfd = fs.openSync(target, "r");
const vprefix = Buffer.alloc(16);
fs.readSync(vfd, vprefix, 0, 16, 0);
const vjsonLen = vprefix.readUInt32LE(12);
const vjson = Buffer.alloc(vjsonLen);
fs.readSync(vfd, vjson, 0, vjsonLen, 16);
const vheader = JSON.parse(vjson.toString("utf8"));
const ventries = [];
(function walk2(node, p) {
  for (const [name, child] of Object.entries(node.files ?? {})) {
    if (child.files) walk2(child, p + name + "/");
    else ventries.push({ path: p + name, e: child });
  }
})(vheader, "");
if (ventries.length !== entries.length) fail("verification failed: entry count mismatch");
const vt = ventries.find((f) => f.path === "out/main/index.js");
const vbuf = Buffer.alloc(vt.e.size);
fs.readSync(vfd, vbuf, 0, vt.e.size, 8 + vprefix.readUInt32LE(4) + parseInt(vt.e.offset, 10));
fs.closeSync(vfd);
if (!vbuf.equals(patched)) fail("verification failed: patched content does not match");
console.log(`asar-patch: ${target} (out/main/index.js ${orig.length} -> ${patched.length} bytes)`);
EOF
node asar-patch.js /opt/OpenCode/resources/app.asar

cd /
rm -rf /tmp/opencode-desktop

# SUIDが無いと非rootユーザーでElectronのサンドボックスが起動できない
chmod 4755 /opt/OpenCode/chrome-sandbox
