# gnome — GNOME デスクトップの不変システムイメージ

[genpack](https://github.com/wbrxcorp/genpack) を用いて、GNOME デスクトップ環境を含む用途特化型の**不変 (immutable) システムイメージ**を生成するアーティファクト定義です。`genpack.json5` を設計図として、Gentoo Linux の stage3 + Portage から最適化された SquashFS イメージをビルドします。

genpack ツールチェーン全体における位置づけについては `~/projects/genpack/docs/introduction.md` を参照してください。

## 概要

- **ベース**: Gentoo `gnome/baremetal` プロファイル、実機・フルVM向けの `genpack/systemimg`
- **デスクトップ**: GNOME Shell + GDM（`user` の自動ログイン付き）
- **主な同梱ソフト**:
  - マルチメディア: VLC / mpv / OBS Studio / GStreamer（VA-API・NVENC 等ハードウェアアクセラレーション対応）、FFmpeg（AMF/QSV/NVENC/VA-API）、SRS（メディアサーバ）
  - グラフィックス: Mesa（vulkan/vaapi/zink）、NVIDIA ドライバ（`kernel-open`）、GIMP
  - リモート/仮想化: GNOME Remote Desktop、Remmina、gnome-connections、virt-viewer、waypipe、Flatpak / Snap
  - AI/計算: llama-cpp、ROCm OpenCL ランタイム（x86_64）、numpy/OpenCV（AVX-512 最適化）
  - 日本語入力: Mozc（ibus）、Noto CJK フォント
- **アーキテクチャ**: `x86_64` を主対象（`i686` 定義もあり）
- **バリアント**: `paravirt`（[vm](https://github.com/shimarin/vm) 上のパラバーチャルマシン向け。NVIDIA ドライバや無線ツールを外し spice-vdagent を追加）

## リポジトリ構成

| パス | 役割 |
|---|---|
| `genpack.json5` | イメージの設計図。パッケージ・USE フラグ・キーワード・ライセンス・ユーザー・サービス等を宣言 |
| `files/` | イメージのルートディレクトリへコピーされるファイル群 |
| `files/build.d/` | ビルド時に実行される仕上げスクリプト（自動ログイン設定、日本語化、各種プラグイン導入など）。最終イメージからは除外される |
| `patches/` | 特定パッケージへ適用する `git diff` 形式のパッチ（`media-libs/mesa`, `net-misc/gnome-remote-desktop` など）。適用対象は `binpkg_excludes` でソース再ビルドを強制 |
| `overlay/` | このアーティファクト固有の ebuild オーバーライド（`sci-ml/llama-cpp` など） |
| `work/` | ビルド作業ディレクトリ（アーキ別。生成物であり編集対象ではない） |
| `gnome-x86_64.squashfs` / `gnome-x86_64.img` | ビルド成果物 |

## ビルド

カレントディレクトリを本リポジトリにして genpack を実行します。

```console
# フルビルド (lower → upper → pack)
$ genpack build

# クロスビルド（要 static qemu-user + binfmt_misc 登録）
$ genpack --arch aarch64 build

# バリアント指定（パラバーチャルマシン向け）
$ genpack --variant paravirt build
```

生成された SquashFS は [vm](https://github.com/shimarin/vm) でそのまま起動して動作確認できます。

```console
$ vm run --display=gtk gnome-$(uname -m).squashfs
```

CLI の詳細は `~/projects/genpack/docs/cli.md` を参照してください。

## ユーザー管理

### ビルド時ユーザー

`genpack.json5` の `users:` で、デスクトップ利用向けの標準ユーザー `user`（uid 1000, 空パスワード, `wheel`/`audio`/`video`/`input`/`usb`/`dialout` 所属）がビルド時に作成され、GDM で自動ログインします。このユーザーはイメージに焼き込まれる `/etc/passwd` に記録されます。

### homectl による追加ユーザー（稼働中）

本イメージのルートファイルシステムは **read-only の SquashFS（不変イメージ）** です。そのため `/etc/passwd` はビルド時に固定され、稼働中に `useradd` で通常ユーザーを追加することはできません。

そこで **systemd-homed** を有効にしています（commit `f715a26`）。homed はユーザーの識別情報を `/etc/passwd` ではなく**ホームディレクトリ側（既定では LUKS 暗号化ボリューム内に埋め込まれた `~/.identity` レコード）**に格納します。これにより、不変イメージのまま稼働中に**永続的な追加ユーザー**を作成でき、イメージのセルフアップデート（root FS 差し替え）をまたいでもユーザーが失われません。

有効化のために `genpack.json5` で以下を設定しています。

- `sys-apps/systemd` に `homed pam openssl` USE フラグ
- `sys-auth/pambase` に `homed` USE フラグ
- `services:` に `systemd-homed` を追加（`systemd-homed.service` を自動起動）

#### 使い方

```console
# 追加ユーザーを作成（ホームは LUKS 暗号化。パスワードは対話入力）
$ sudo homectl create alice --member-of=wheel,audio,video,input

# 一覧・詳細確認
$ homectl list
$ homectl inspect alice

# 手動でのアクティベート（解錠・マウント）/ ディアクティベート
#   ※通常はログイン/ログアウトに連動して自動的に行われる
$ sudo homectl activate alice
$ sudo homectl deactivate alice

# プロパティ変更（例: 所属グループを追加）
$ sudo homectl update alice --member-of=wheel,audio,video,input,dialout

# パスワード変更 / ユーザー削除
$ sudo homectl passwd alice
$ sudo homectl remove alice
```

#### 補足

- homed のホームディレクトリは既定で **LUKS 暗号化**され、ログイン時にパスワードで解錠、ログアウト時に自動でロック/アンマウントされます。
- 作成したユーザーは **GDM のログイン画面から直接ログイン**できます。
- `/etc/passwd`・`/etc/shadow` を一切変更しないため、不変イメージの設計と両立し、イメージ更新後もユーザー情報が永続します。
- 暗号化を避けたい場合は `homectl create alice --storage=directory`（`/home/alice.homedir` に平文ディレクトリで格納）などのストレージ指定も可能です。詳細は `man homectl` を参照してください。
