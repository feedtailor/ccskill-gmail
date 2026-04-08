# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

ccskill-gmail は Claude Code 用の Gmail スキル。GAS (Google Apps Script) Web App を通じて Gmail を操作する。

**設計原則**:
- 読み取り中心（検索・閲覧に特化）
- 下書き作成まで（送信は人間が確認してから行う）
- 永久削除 API は提供しない

## アーキテクチャ

```
Claude Code (Skill)
  ↓ .ccskill-gmail/api get|post|download|save-html|save-pdf
  ↓ (Bearer OAuth token 自動付与)
GAS Web App (standalone, MYSELF access)
  ↓
Gmail (GmailApp)
```

ccskill-spreadsheet と同じアーキテクチャパターンを採用。

## 参照

- **ディレクトリ構成**: コード探索で確認
- **セキュリティ設計判断**: @docs/security-decisions.md
- **API アクション一覧・ルーティング**: @gas-template/main.js （テーブル駆動方式。switch 文は存在しない）
- **GAS スコープ**: @gas-template/appsscript.json
- **各種コマンド**: @README.md または `ccskill-gmail --help`

## テスト手順

GAS コードを変更したら、必ずデプロイしてテストすること。

```bash
# 1. テスト用プロジェクトにデプロイ（プロジェクトのパスはユーザーに確認すること）
cd ~/projects/<テスト用プロジェクト>
~/projects/ccskill-gmail/ccskill-gmail update --force --yes .

# 2. テスト用プロジェクトに cd してからテスト実行
cd ~/projects/<テスト用プロジェクト>
.ccskill-gmail/api get action=...
.ccskill-gmail/api post '{"action":...}'
```

**注意事項**:
- テストは必ず対象プロジェクトに `cd` してから行う（`.ccskill-gmail/api` がカレントディレクトリ依存）
- デプロイは `ccskill-gmail update` を使う（`push_gas` を直接呼ばない）
- Bash ツールでは `$()` を避けてパイプで繋ぐ（`$()` は sandbox の確認プロンプトを発生させる）
- curl の exit code 56 やレスポンスが HTML の場合、まず OAuth トークン期限切れを疑う（`auth.sh` の `gas_token` が自動リフレッシュする仕組みがある。sandbox でリフレッシュがブロックされる場合は sandbox 無効化が必要）

## コミットメッセージ規約

1行目は `type: 概要 (#issue番号)` 形式（Conventional Commits）。

| type | 用途 | update 時の履歴表示 |
|------|------|-------------------|
| `feat` | 新機能 | 表示される |
| `fix` | バグ修正 | 表示される |
| `docs` | ドキュメントのみ | 表示されない |
| `refactor` | リファクタ | 表示されない |
| `chore` | 雑務（CI、依存更新等） | 表示されない |
| `test` | テスト | 表示されない |

`ccskill-gmail update` の履歴表示は `feat:` と `fix:` のみ抽出する（マージコミットも除外）。ユーザーに影響する変更だけを見せるため。

## コード規約

- シェルスクリプト: `cp` ではなく `/bin/cp` を使用（macOS alias 対策）
- 環境変数: `CCSKILL_GMAIL_DIR` はディスパッチャが設定
- lib/ の関数は副作用を最小限に（jq なしでも graceful degradation）
