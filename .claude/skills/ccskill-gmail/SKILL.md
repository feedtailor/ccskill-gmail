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

**セキュリティ**: Web App は「自分のみ (Only myself)」で公開されており、clasp の OAuth トークンによる認証が必要です。`gas_token` ヘルパー関数がトークンの自動取得・リフレッシュを行います。

## 重要なルール

**以下のルールは必ず守ってください。違反すると Claude Code のセキュリティ確認プロンプトが発生し、ユーザー体験を大きく損ないます。**

1. **1回の Bash ツール呼び出しにつき API コールは1つだけ**
   - 複数の API 結果が必要な場合は、Bash ツールを複数回（並列可）呼び出す
   - 1つの Bash コマンド内に複数の `ccskill-get` / `ccskill-post` を `&&` や `;` で連結しない

2. **`$()` コマンド置換の中に API コールを入れない**
   - `messageId=$(ccskill-get ...)` のようなネストは禁止
   - まず検索結果を取得し、次の Bash 呼び出しで ID を使う

3. **ファイル保存には専用ヘルパーを使う（`>` リダイレクト禁止）**
   - 添付ファイル保存: `_gmail_download` を使う（`ccskill-get ... | jq | base64 -d > file` は禁止）
   - メール PDF 化: `_gmail_save_pdf` を使う（HTML 取得 → PDF 変換を一括実行）
   - HTML 保存: `_gmail_save_html` を使う（`ccskill-get ... | jq -r > file` は禁止）
   - 理由1: `>` リダイレクトは Claude Code のセキュリティ確認プロンプトを発生させる
   - 理由2: 大きなレスポンスをパイプで直接処理するとデータが途切れる問題がある

```bash
# OK: 別々の Bash ツール呼び出しで実行
# [Bash 1回目] 検索
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="subject:報告書"

# [Bash 2回目] 上の結果から得た ID を使って取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=19bf7f25b96ab637
```

```bash
# NG: 1つの Bash に複数 API を詰め込む
source .ccskill-gmail/api.sh && ccskill-get ... && echo "---" && source .ccskill-gmail/api.sh && ccskill-get ...

# NG: $() 内に API コール
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_message messageId=$(ccskill-get ... | jq -r ...)
```

```bash
# OK: ヘルパーでファイル保存（確認プロンプトなし・データ途切れなし）
source .ccskill-gmail/api.sh && _gmail_download "$GMAIL_ENDPOINT" MESSAGE_ID 0 ./report.pdf
source .ccskill-gmail/api.sh && _gmail_save_pdf "$GMAIL_ENDPOINT" MESSAGE_ID ./email.pdf
source .ccskill-gmail/api.sh && _gmail_save_html "$GMAIL_ENDPOINT" MESSAGE_ID ./email.html

# NG: パイプ + リダイレクトでファイル保存（確認プロンプト発生・大きなファイルでデータ途切れ）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_attachment messageId=MSG attachmentIndex=0 | jq -r '.data.content' | base64 -d > ./report.pdf
```

---

## クイックスタート

### 1. 初期化 + コマンド実行

**重要: Claude Code の Bash ツールは呼び出しごとに別プロセスで実行されるため、`source` と `ccskill-get` / `ccskill-post` は必ず `&&` で繋いで同一コマンドとして実行してください。**

```bash
# 未読メール検索
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread"

# ラベル一覧
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_labels

# 日本語もそのまま渡せる（自動 URL エンコード）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="from:田中 subject:報告書"
```

### 2. POST リクエスト（書き込み）

```bash
# 下書き作成
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"user@example.com","subject":"件名","body":"本文"}'
```

**長い JSON は Write ツール + `@file` パターンを使用してください。**
`cat` heredoc は使用禁止です（`Bash(cat:*)` の `*` は改行にマッチせず、毎回許可プロンプトが出るため）。

```
# Step 1: Write ツールで JSON ファイルを作成（許可プロンプト不要）
Write("/tmp/payload.json") に以下の内容:
{"action":"create_draft","to":"to@example.com","cc":"cc@example.com","subject":"件名","body":"長い本文..."}
```

```bash
# Step 2: Bash で送信
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" @/tmp/payload.json
```

### GET/POST の使い分け

| 操作 | メソッド | 例 |
|------|---------|-----|
| search, get_thread, get_message 等 | GET（ccskill-get） | `action=search query="is:unread"` |
| create_draft, mark_read 等 | POST（ccskill-post） | `'{"action":"create_draft",...}'` |

誤って ccskill-post で読み取り系を呼ぶと `Unknown action` エラーになります。

---

## 日本語の扱い

ccskill-get は値を自動的に URL エンコードするため、日本語をそのまま使えます:

```bash
# そのまま使える
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="from:田中 subject:報告書"

# 手動エンコードは不要
# curl ... "$(jq -sRr @uri <<< '田中')"  # この書き方はもう不要
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
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT"

# メール検索
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=10

# スレッド取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=THREAD_ID

# メッセージ詳細
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_message messageId=MESSAGE_ID

# ラベル一覧
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_labels

# 未読数取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count

# 特定ラベルの未読数
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count label=重要

# 添付ファイル一覧
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_attachments messageId=MESSAGE_ID

# 添付ファイルダウンロード（推奨: _gmail_download ヘルパー）
source .ccskill-gmail/api.sh && _gmail_download "$GMAIL_ENDPOINT" MESSAGE_ID 0 /tmp/attachment.pdf

# メール PDF 化（推奨: _gmail_save_pdf ヘルパー — HTML取得+PDF変換を一括実行）
source .ccskill-gmail/api.sh && _gmail_save_pdf "$GMAIL_ENDPOINT" MESSAGE_ID ./email.pdf

# メール本文 HTML 保存
source .ccskill-gmail/api.sh && _gmail_save_html "$GMAIL_ENDPOINT" MESSAGE_ID ./email.html

# メール本文 HTML 保存（ヘッダーなし）
source .ccskill-gmail/api.sh && _gmail_save_html "$GMAIL_ENDPOINT" MESSAGE_ID ./email.html false

# 下書き一覧
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_drafts

# 下書き一覧（件数指定）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_drafts maxResults=50

# プロフィール情報取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_profile
```

### 書き込み (POST)

```bash
# 下書き作成
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"recipient@example.com","subject":"件名","body":"本文"}'

# CC/BCC 付き下書き
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"to@example.com","cc":"cc@example.com","bcc":"bcc@example.com","subject":"件名","body":"本文"}'

# HTML メール下書き（body はプレーンテキストフォールバック）
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"to@example.com","subject":"件名","body":"本文","htmlBody":"<h1>件名</h1><p>本文</p>"}'

# 返信下書き作成
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"ご連絡ありがとうございます。"}'

# 既読にする
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","threadId":"THREAD_ID"}'

# 未読にする
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_unread","threadId":"THREAD_ID"}'

# ラベル追加
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# ラベル削除
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"remove_label","threadId":"THREAD_ID","label":"対応済"}'

# アーカイブ
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"archive","threadId":"THREAD_ID"}'

# ゴミ箱に移動
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"move_to_trash","threadId":"THREAD_ID"}'

# 下書き更新
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"update_draft","draftId":"DRAFT_ID","subject":"新しい件名"}'

# 下書き削除
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"delete_draft","draftId":"DRAFT_ID"}'
```

---

## Gmail 検索クエリ

`search` API は Gmail の検索構文をそのまま使用できます:

```bash
# 未読メール
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread"

# 特定の送信者から
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="from:boss@company.com"

# 件名に含む（日本語も自動エンコード）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="subject:請求書"

# 日付指定
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="after:2024/01/01"

# 添付ファイル付き
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="has:attachment"

# 複合条件
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread from:important@example.com"
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

```bash
# jq でパース
source .ccskill-gmail/api.sh && RESULT=$(ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread") && echo "$RESULT" | jq '.data.threads[].subject'

# エラーチェック
source .ccskill-gmail/api.sh && RESULT=$(ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread") && if echo "$RESULT" | jq -e '.ok == true' > /dev/null 2>&1; then echo "成功"; else echo "エラー: $(echo "$RESULT" | jq -r '.error')"; fi
```

---

## ワークフロー例

### 未読メールを確認して返信下書きを作成

```bash
# 1. 未読メール一覧を取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=5

# 2. 特定のスレッドを詳細表示
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=19bf7f25b96ab637

# 3. 返信下書きを作成
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"ご連絡ありがとうございます。\n\n承知いたしました。"}'

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

## 関連ドキュメント

- [API リファレンス](reference/) - 全 API の詳細仕様
- [トラブルシューティング](troubleshooting.md) - よくある問題と解決策
- [ワークフロー例](examples.md) - 実践的な使用例
