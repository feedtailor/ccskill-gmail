# コマンド一覧

[← README に戻る](../README.ja.md) ・ [English](commands.md)

`ccskill-gmail <コマンド> [引数...]`。組み込みの要約は `ccskill-gmail help` で表示できます。

## セットアップ

| コマンド | 説明 |
|---|---|
| `./ccskill-gmail setup` | 初回インストール一式。clasp のローカル導入・PATH 登録に続けて、スキルの登録（`skill install`）と、未登録なら Gmail アカウントの登録（`account add`）まで実行 |
| `ccskill-gmail uninstall --all [--yes\|--dry-run]` | このマシンから ccskill-gmail を一括撤去（ユーザースキル・全アカウント登録・CLI symlink）。GAS と clasp トークンは手動削除 |

## アカウント

| コマンド | 説明 |
|---|---|
| `ccskill-gmail account add [--label NAME]` | Gmail アカウントを登録（共有 GAS を作成し、認可のためブラウザが開く）。`--label` は任意で、省略すると 2 個目以降は認証後にラベルを尋ねる |
| `ccskill-gmail account list` | 登録アカウントの一覧（`*` がデフォルト） |
| `ccskill-gmail account default <email\|label>` | デフォルトアカウントの変更 |
| `ccskill-gmail account update [<email\|label>]` | 全（または指定）アカウントの共有 GAS を再デプロイ |
| `ccskill-gmail account remove <email\|label>` | アカウント登録を解除 |

## スキル登録

| コマンド | 説明 |
|---|---|
| `ccskill-gmail skill install [--copy]` | ユーザースキルを登録（`~/.claude/skills/`）。既定は symlink、`--copy` は実体コピー |
| `ccskill-gmail skill uninstall` | ユーザースキル登録を解除 |

## ディレクトリ固定

| コマンド | 説明 |
|---|---|
| `ccskill-gmail bind <email\|label> [DIR]` | ディレクトリをアカウントに固定（`binding.json` を書く） |
| `ccskill-gmail unbind [--purge-legacy] [DIR]` | 固定を解除（任意でレガシーのプロジェクト単位 install ファイルも掃除） |

## API の利用

| コマンド | 説明 |
|---|---|
| `ccskill-gmail api whoami` | どのアカウントに・なぜ解決されるかを表示 |
| `ccskill-gmail api get action=... [params]` | 読み取り操作（search, get_thread, get_profile, …） |
| `ccskill-gmail api post '{"action":...}'` | 書き込み操作（create_draft, add_label, …） |
| `ccskill-gmail api download\|save-html\|save-pdf ...` | 添付ファイルのダウンロード / メール本文の保存 |

API 仕様の全体は [SKILL.md](../.claude/skills/ccskill-gmail/SKILL.md) を参照してください。

## 状況確認・診断

| コマンド | 説明 |
|---|---|
| `ccskill-gmail info [--json] [DIR]` | ディレクトリの詳細表示（アカウント、権限、未読数） |
| `ccskill-gmail status [--refresh]` | インストール状況の一覧 |
| `ccskill-gmail doctor` | 環境・セットアップの診断 |
| `ccskill-gmail history [--all]` | API 操作の監査ログ表示 |

## 移行・メンテナンス

| コマンド | 説明 |
|---|---|
| `ccskill-gmail migrate [--dry-run]` | 中央化以前のプロジェクト単位 install をアカウントレジストリに集約 |
| `ccskill-gmail update-all` | 全アカウントの共有 GAS と、残っているレガシーのプロジェクト単位 install を更新 |
| `ccskill-gmail register <PATH>...` | 既存インストールの登録 |
| `ccskill-gmail release [DIR]` | 配布用 zip ファイルの作成 |

## プロジェクト単位（レガシー / 上級者向け）

専用 GAS を持つプロジェクト単位 install 向けで、標準のアカウント共有セットアップでは不要です。

| コマンド | 説明 |
|---|---|
| `ccskill-gmail install [--account NAME] [--dedicated] [DIR]` | プロジェクトをアカウントに固定（`--dedicated` で専用 GAS を作成） |
| `ccskill-gmail uninstall [DIR]` | プロジェクト単位 install のローカルファイルを削除 |
| `ccskill-gmail update [DIR]` | プロジェクト 1 つを更新 |
| `ccskill-gmail apply-config [DIR]` | `config.js` の変更を専用 GAS に反映 |
