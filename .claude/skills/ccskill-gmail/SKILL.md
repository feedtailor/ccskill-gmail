---
name: ccskill-gmail
description: Gmail の検索・閲覧・下書き作成を行います。curl 経由で GAS Web API を呼び出します。送信は安全のため手動で行う設計です。
allowed-tools: Bash, Write
---

# Gmail Skill

Gmail の検索・閲覧・下書き作成を行うための Claude Code Skill です。

## 概要

このスキルは Google Apps Script (GAS) で構築された Web API を通じて、Gmail を操作します。メールの検索、閲覧、下書き作成が可能です。

**設計方針**: 送信機能は意図的に含めていません。下書きを作成し、人間が Gmail で確認してから送信する安全設計です。

**セキュリティ**: Web App は「自分のみ (Only myself)」で公開されており、clasp の OAuth トークンによる認証が必要です。`.ccskill-gmail/api` スクリプトがトークンの自動取得・リフレッシュを行います。

<important if="you are calling .ccskill-gmail/api or constructing a Bash command for Gmail">

## Bash コマンド構築ルール（確認プロンプト防止）

以下のルールに1つでも違反すると、ユーザーにセキュリティ確認プロンプトが表示され操作が中断する。**例外なく全ルールを守ること。**

**MUST（必須）:**
- 1回の Bash 呼び出しにつき API コールは1つだけ（複数必要なら Bash を並列で複数回呼ぶ）
- ファイル保存は専用サブコマンド（`download` / `save-pdf` / `save-html`）を使う
- 長い JSON は Write ツールでファイルに書き出し、`post @/tmp/payload.json` で送る
- API レスポンスの JSON は Claude が直接読んで情報を抽出する（パイプ処理は不要）

**NEVER（厳禁）:**
- NEVER use `$()` or backticks anywhere in the command — **no exceptions, even for simple values like `$(echo '...')`**. Variable values must be written inline as literals.
- NEVER chain: `.ccskill-gmail/api get ... && .ccskill-gmail/api get ...`
- NEVER redirect: `.ccskill-gmail/api get ... > file`
- NEVER pipe to scripts: `.ccskill-gmail/api get ... | python3 -c "..."`
- NEVER pipe to text processors: `.ccskill-gmail/api get ... | awk/sed/perl`
- NEVER use cat heredoc: `cat <<EOF` で JSON を作らない

**唯一の例外**: `| jq '...'` による簡易フィルタのみ許可（レスポンスが大きい場合の出力削減用）

### OK / NG 例

```bash
# OK: 別々の Bash ツール呼び出しで実行
# [Bash 1回目] 検索
.ccskill-gmail/api get action=search query="subject:報告書"

# [Bash 2回目] 上の結果から得た ID を使って取得
.ccskill-gmail/api get action=get_thread threadId=19bf7f25b96ab637
```

```bash
# NG: 1つの Bash に複数 API を詰め込む
.ccskill-gmail/api get ... && .ccskill-gmail/api get ...

# NG: $() を使っている（値がリテラルでも禁止）
.ccskill-gmail/api get action=get_message messageId=$(echo '19cad22f211cf5b1')

# NG: $() 内に API コール
.ccskill-gmail/api get action=get_message messageId=$(.ccskill-gmail/api get ... | jq -r ...)
```

```bash
# OK: 専用サブコマンドでファイル保存（確認プロンプトなし・データ途切れなし）
.ccskill-gmail/api download MESSAGE_ID 0 ./report.pdf
.ccskill-gmail/api save-pdf MESSAGE_ID ./email.pdf
.ccskill-gmail/api save-html MESSAGE_ID ./email.html

# NG: パイプ + リダイレクトでファイル保存（確認プロンプト発生・大きなファイルでデータ途切れ）
.ccskill-gmail/api get action=get_attachment messageId=MSG attachmentIndex=0 | jq -r '.data.content' | base64 -d > ./report.pdf
```

```bash
# OK（推奨）: パイプなしで API を呼び、Claude がレスポンス JSON を直接読む
.ccskill-gmail/api get action=get_thread threadId=19cadf598c49fb2c

# OK: jq で出力を絞る（レスポンスが大きい場合）
.ccskill-gmail/api get action=get_thread threadId=19cadf598c49fb2c | jq '.data.messages[] | {from, to, date, subject}'

# NG: python3 でパース（確認プロンプト発生）
.ccskill-gmail/api get action=get_thread threadId=... | python3 -c "import json, sys; ..."

# NG: awk/sed でパース（確認プロンプト発生）
.ccskill-gmail/api get action=get_thread threadId=... | awk '{...}'
```

</important>

---

## クイックスタート

### 1. コマンド実行

```bash
# 未読メール検索
.ccskill-gmail/api get action=search query="is:unread"

# ラベル一覧
.ccskill-gmail/api get action=list_labels

# 日本語もそのまま渡せる（自動 URL エンコード）
.ccskill-gmail/api get action=search query="from:田中 subject:報告書"
```

### 2. POST リクエスト（書き込み）

```bash
# 下書き作成
.ccskill-gmail/api post '{"action":"create_draft","to":"user@example.com","subject":"件名","body":"本文"}'
```

**長い JSON は MUST: Write ツール + `@file` パターンを使う。** `cat` heredoc は NEVER 使わないこと（確認プロンプトが発生する）。

```
# Step 1: Write ツールで JSON ファイルを作成（許可プロンプト不要）
Write("/tmp/payload.json") に以下の内容:
{"action":"create_draft","to":"to@example.com","cc":"cc@example.com","subject":"件名","body":"長い本文..."}
```

```bash
# Step 2: Bash で送信
.ccskill-gmail/api post @/tmp/payload.json
```

### GET/POST の使い分け

| 操作 | メソッド | 例 |
|------|---------|-----|
| search, get_thread, get_message 等 | GET（get サブコマンド） | `action=search query="is:unread"` |
| create_draft, mark_read 等 | POST（post サブコマンド） | `'{"action":"create_draft",...}'` |

誤って post で読み取り系を呼ぶと `Unknown action` エラーになります。

---

## 日本語の扱い

get サブコマンドは値を自動的に URL エンコードするため、日本語をそのまま使えます:

```bash
# そのまま使える
.ccskill-gmail/api get action=search query="from:田中 subject:報告書"

# 手動エンコードは不要
```

---

## API 一覧

### 読み取り (GET)

| アクション | 説明 | パラメータ |
|-----------|------|-----------|
| (なし) | ヘルスチェック | - |
| search | メール検索 | `query` (必須), `maxResults` (任意, デフォルト20) |
| get_thread | スレッド取得 | `threadId` (必須) |
| get_message | メッセージ詳細 | `messageId` (必須) |
| list_labels | ラベル一覧 | - |
| get_unread_count | 未読メール数取得 | `label` (任意, デフォルト INBOX) |
| list_attachments | 添付ファイル一覧 | `messageId` (必須) |
| get_attachment | 添付ファイル取得 | `messageId` (必須), `attachmentIndex` (必須, 0始まり) |
| get_message_html | メール本文 HTML 取得 | `messageId` (必須), `includeHeaders` (任意, デフォルト true) |
| list_drafts | 下書き一覧取得 | `maxResults` (任意, デフォルト 20, 上限 100) |
| get_profile | プロフィール情報取得 | - |

### 書き込み (POST)

| アクション | 説明 | パラメータ |
|-----------|------|-----------|
| create_draft | 新規メールの下書き作成 | `to`, `subject`, `body` (必須), `cc`, `bcc`, `htmlBody`, `attachments` (任意) |
| create_reply_draft | 既存スレッドへの返信下書き作成 | `threadId`, `body` (必須), `cc`, `bcc`, `htmlBody`, `attachments`, `skipSelf`, `replyAll` (任意) |
| update_draft | 下書き更新 | `draftId` (必須), `to`, `subject`, `body`, `cc`, `bcc`, `htmlBody` (任意) |
| delete_draft | 下書き削除 | `draftId` (必須) |
| mark_read | 既読にする | `threadId` または `messageId` (いずれか必須) |
| mark_unread | 未読にする | `threadId` または `messageId` (いずれか必須) |
| add_label | ラベル追加 | `threadId`, `label` (必須) |
| remove_label | ラベル削除 | `threadId`, `label` (必須) |
| archive | アーカイブ | `threadId` (必須) |
| move_to_trash | ゴミ箱に移動 | `threadId` (必須) |

> 詳細: [reference/](reference/)

---

## コマンドテンプレート

### 読み取り (GET)

```bash
# ヘルスチェック
.ccskill-gmail/api get

# メール検索
.ccskill-gmail/api get action=search query="is:unread" maxResults=10

# スレッド取得
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID

# メッセージ詳細
.ccskill-gmail/api get action=get_message messageId=MESSAGE_ID

# ラベル一覧
.ccskill-gmail/api get action=list_labels

# 未読数取得
.ccskill-gmail/api get action=get_unread_count

# 特定ラベルの未読数
.ccskill-gmail/api get action=get_unread_count label=重要

# 添付ファイル一覧
.ccskill-gmail/api get action=list_attachments messageId=MESSAGE_ID

# 添付ファイルダウンロード（推奨: download サブコマンド）
.ccskill-gmail/api download MESSAGE_ID 0 /tmp/attachment.pdf

# メール PDF 化（推奨: save-pdf サブコマンド — HTML取得+PDF変換を一括実行）
.ccskill-gmail/api save-pdf MESSAGE_ID ./email.pdf

# メール本文 HTML 保存
.ccskill-gmail/api save-html MESSAGE_ID ./email.html

# メール本文 HTML 保存（ヘッダーなし）
.ccskill-gmail/api save-html MESSAGE_ID ./email.html false

# 下書き一覧
.ccskill-gmail/api get action=list_drafts

# 下書き一覧（件数指定）
.ccskill-gmail/api get action=list_drafts maxResults=50

# プロフィール情報取得
.ccskill-gmail/api get action=get_profile
```

### 書き込み (POST)

```bash
# 下書き作成
.ccskill-gmail/api post '{"action":"create_draft","to":"recipient@example.com","subject":"件名","body":"本文"}'

# CC/BCC 付き下書き
.ccskill-gmail/api post '{"action":"create_draft","to":"to@example.com","cc":"cc@example.com","bcc":"bcc@example.com","subject":"件名","body":"本文"}'

# HTML メール下書き（body はプレーンテキストフォールバック）
.ccskill-gmail/api post '{"action":"create_draft","to":"to@example.com","subject":"件名","body":"本文","htmlBody":"<h1>件名</h1><p>本文</p>"}'

# 返信下書き作成
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"ご連絡ありがとうございます。"}'

# 既読にする
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 未読にする
.ccskill-gmail/api post '{"action":"mark_unread","threadId":"THREAD_ID"}'

# ラベル追加
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# ラベル削除
.ccskill-gmail/api post '{"action":"remove_label","threadId":"THREAD_ID","label":"対応済"}'

# アーカイブ
.ccskill-gmail/api post '{"action":"archive","threadId":"THREAD_ID"}'

# ゴミ箱に移動
.ccskill-gmail/api post '{"action":"move_to_trash","threadId":"THREAD_ID"}'

# 下書き更新
.ccskill-gmail/api post '{"action":"update_draft","draftId":"DRAFT_ID","subject":"新しい件名"}'

# 下書き削除
.ccskill-gmail/api post '{"action":"delete_draft","draftId":"DRAFT_ID"}'
```

---

## Gmail 検索クエリ

`search` API は Gmail の検索構文をそのまま使用できます:

```bash
# 未読メール
.ccskill-gmail/api get action=search query="is:unread"

# 特定の送信者から
.ccskill-gmail/api get action=search query="from:boss@company.com"

# 件名に含む（日本語も自動エンコード）
.ccskill-gmail/api get action=search query="subject:請求書"

# 日付指定
.ccskill-gmail/api get action=search query="after:2024/01/01"

# 添付ファイル付き
.ccskill-gmail/api get action=search query="has:attachment"

# 複合条件
.ccskill-gmail/api get action=search query="is:unread from:important@example.com"
```

---

## レスポンス処理

**成功時:**
```json
{"ok": true, "data": {...}}
```

**エラー時:**
```json
{"ok": false, "error": "エラーメッセージ"}
```

**Claude は出力された JSON を直接読んで必要な情報を抽出できる。** 基本的にパイプ処理は不要。レスポンスが大きすぎて出力が途切れる場合のみ、jq で出力を絞ることを検討する。

```bash
# 推奨: パイプなしで実行し、Claude がレスポンスを直接読む
.ccskill-gmail/api get action=search query="is:unread"

# レスポンスが大きい場合のみ: jq で出力を絞る
.ccskill-gmail/api get action=search query="is:unread" | jq '.data.threads[] | {subject, from, date}'
```

---

## ワークフロー例

### 未読メールを確認して返信下書きを作成

```bash
# 1. 未読メール一覧を取得
.ccskill-gmail/api get action=search query="is:unread" maxResults=5

# 2. 特定のスレッドを詳細表示
.ccskill-gmail/api get action=get_thread threadId=19bf7f25b96ab637

# 3. 返信下書きを作成
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"ご連絡ありがとうございます。\n\n承知いたしました。"}'

# 4. Gmail で下書きを確認・送信
# https://mail.google.com/mail/u/0/#drafts
```

---

## エラー時の再試行

API 呼び出しでエラーが発生した場合は、まず再試行してください。以下のような一時的なエラーは再試行で解決することが多いです:

- **GAS コールドスタート**: 初回アクセス時にタイムアウトする場合がある（`--max-time 60` で対応済みだが稀に超過）
- **Anthropic API エラー**: Claude Code 自体のバックエンドで 500 エラーが発生する場合がある。これはスキルの問題ではなく一時的な障害
- **ネットワークエラー**: 通信の一時的な問題

再試行しても解決しない場合は、[トラブルシューティング](troubleshooting.md) を参照してください。

---

## 制限事項

- **パーミッション制御**: `config.js` の `permissions` 設定により、特定のアクションを allow/deny で制御できます（Claude Code の allow/deny パターンに準拠）。`move_to_trash` はデフォルトで無効化されています。有効にするには `config.js` の `permissions.deny` から削除し、`ccskill-gmail apply-config` を実行してください。
- **送信機能なし**: 下書き作成のみ（送信は Gmail UI で手動）
- **認証**: `clasp login` 済みで、Web App は「自分のみ (Only myself)」で公開されている必要があります
- **トークン管理**: `gas_token` 関数が自動リフレッシュを行います。`clasp login` のセッションが切れた場合は再ログインが必要です
- **OAuth 認可**: 初回インストール時にブラウザで OAuth 認可が必要です（1回のみ）
- **エンドポイント制限**: `https://script.google.com/*` のみ許可（セキュリティ保護）
- **レート制限**: GAS の実行時間制限（6分/実行）が適用されます
- **添付ファイル**: ダウンロード（`list_attachments` / `get_attachment`）、下書き作成時の添付（`create_draft` / `create_reply_draft` の `attachments` パラメータ）に対応
- **添付ファイルサイズ制限**: `get_attachment` は 5MB 超のファイルをエラーにします。下書き作成時の添付も合計 5MB が上限です。大きなファイルは Gmail UI で操作してください
- **返信下書きの宛先変更不可**: `update_draft` で返信下書きの to（宛先）は変更できません（GmailApp API の制約）。cc / bcc / body / subject は変更可能です。宛先の変更が必要な場合は、ユーザーに「Gmail の下書き確認時に手動で宛先を変更してください」と案内してください

---

---

## 操作履歴

Gmail Skill の全操作はローカルに自動記録されます。

### 履歴の確認

```bash
# 最近の操作を確認（デフォルト: 最新20件、人間可読形式）
ccskill-gmail history

# エラーのみ表示
ccskill-gmail history list --errors

# JSON 形式で出力（Claude や jq での処理用）
ccskill-gmail history list --json

# 最新 50 件
ccskill-gmail history list 50

# 特定アクションのみ
ccskill-gmail history list --action create_draft

# 指定日以降
ccskill-gmail history list --since 2026-03-17

# ログをクリア（--yes 必須）
ccskill-gmail history clear --yes
```

ユーザーに「AI が何をしたか」を聞かれた場合はこのコマンドで確認できます。

### プライバシーノート

- **記録される情報**: アクション名、識別 ID（threadId 等）、成功/失敗、実行時間
- **記録されない情報**: メール本文、宛先、件名、検索クエリの内容（セキュリティ上、意図的に記録しない）
- **詳細の確認**: ユーザーから「何のメールだったか」等を聞かれた場合は、履歴の threadId / messageId を使って `get_thread` / `get_message` で自分で確認すること
- **保存場所**: `.ccskill-gmail/history/audit.jsonl`（ローカルのみ、git 対象外推奨）
- **無効化**: `CCSKILL_GMAIL_HISTORY=off` 環境変数で記録を停止可能

---

## 関連ドキュメント

- [API リファレンス](reference/) - 全 API の詳細仕様
- [トラブルシューティング](troubleshooting.md) - よくある問題と解決策
- [ワークフロー例](examples.md) - 実践的な使用例
