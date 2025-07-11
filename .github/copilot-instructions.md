# Copilot Instructions

This file contains instructions for Copilot to follow when generating code.

## genpack.json(or genpack.json5)

genpack.json(またはgenpack.json5)は、[genpack](https://github.com/wbrxcorp/genpack)の設定ファイルです。
genpackはGentoo Linuxのstage3をベースに、指定のパッケージを含めたルートファイルシステムイメージを
squashfs形式で生成するツールです。genpackを使用して生成される特定の目的のためにカスタマイズされたOS
イメージをアーティファクトと呼んでいます。

genpack.json(genpack.json5)は、JSON(またはJSON5)形式で記述され、以下のようなトップレベル・プロパティを持ちます。

- `name`: (string) パッケージの名前を指定します。
- `outfile`: (string) 出力ファイル名を指定します。
- `devel`: (boolean) 開発用のパッケージを含めるかどうかを指定します。
- `packages`: (list of str) インストールするパッケージのリストを指定します。
- `buildtime_packages`: (list of str) ビルド時に必要なパッケージのリストを指定します。
- `devel_packages`: (list of str) 開発用のパッケージのリストを指定します。
- `accept_keywords`: (dict) Portageの package.accept_keywordsファイルに相当する内容を指定します。
- `use`: (dict) Portageの package.useファイルに相当する内容を指定します。
- `mask`: (dict) Portageの package.maskファイルに相当する内容を指定します。
- `license`: (dict) Portageの package.licenseファイルに相当する内容を指定します。
- `binpkg_excludes`: (list of string) バイナリパッケージの使用を抑制するパッケージのリストを指定します。
- `users`: (list of dict) ルートファイルシステムに追加するユーザーのリストを指定します。
- `groups`: (list of dict) ルートファイルシステムに追加するグループのリストを指定します。
- `services`: (list of str) ルートファイルシステムに追加するサービスのリストを指定します。

また、ビルドの実行環境によって `arch` プロパティと、genpackのオプション指定によって `variants` プロパティの
配下にある適切な設定が選択され上記トップレベルのプロパティにマージされます。

arch例

```json
"arch":{
    "x86_64": {
        "accept_keywords": {
            "dev-libs/openssl": "~amd64"
        }
    }
    "aarch64": {
        "accept_keywords": {
            "dev-libs/openssl": "~arm64"
        },
        "use": {
            "sys-apps/busybox": "-static"
        }
    }
}
```

variants例

```json
"variants": {
    "minimal": {
        "devel": false,
        "packages": [
            "sys-apps/busybox",
        ]
    },
    "full": {
        "devel": true,
        "packages": [
            "sys-apps/busybox",
            "dev-libs/openssl",
            "dev-libs/libxml2"
        ]
    }
}
```

## filesディレクトリ

`files`ディレクトリは、genpackの設定ファイルに記述されたパッケージのインストール後に
イメージに組み込まれるファイルを配置するためのディレクトリです。このディレクトリ内に
配置されたファイルやディレクトリは、イメージのビルド時にルートディレクトリを基準として
コピーされます。

files/build.d ディレクトリに設置されたスクリプトは、ファイルのコピー後にそれぞれ実行されます。
これらのスクリプトは、イメージのビルドプロセスの一部として実行され、必要な設定や
ファイルの配置を行うことができます。build.dディレクトリ以下に設置されたスクリプトは
実行属性が付与されていればそのまま実行され、そうでない場合はファイル名のサフィックスに
基づいて適当なインタプリタで実行されます。

files/build.d/<username> ディレクトリは、ユーザーごとのビルドスクリプトを配置するためのディレクトリです。
このディレクトリ内に配置されたスクリプトは、対応するユーザーのuid/gidで実行されます。

files/build.dディレクトリは最終的なイメージファイルからは除外されます。

## 参考リソース

https://github.com/orgs/genpack-artifacts/repositories 以下に genpackアーティファクトの
リポジトリが公開されています。各リポジトリの genpack.json(またはgenpack.json5)を参照することで、
genpackの設定方法やよく使用されているパターンの情報を得ることができます。

https://github.com/wbrxcorp/genpack-overlay は、genpackから使用できる様々なパッケージの
オーバーレイを提供しています。特に genpack/systemimg は実機またはフルバーチャルマシンでの
使用を目的としたシステムイメージのベースを、genpack/paravirtは [vm](https://github.com/shimarin/vm)
を使用したパラバーチャルな仮想マシンでの使用を目的としたシステムイメージのベースを提供しています。
