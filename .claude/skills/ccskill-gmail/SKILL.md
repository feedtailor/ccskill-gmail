---
name: ccskill-gmail
description: Gmail の検索・閲覧・下書き作成を行います。メールの確認、未読チェック、返信下書きの作成などに使用してください。curl 経由で GAS Web API を呼び出します。送信は安全のため手動で行う設計です。
allowed-tools: Bash
---

# Gmail Skill

Gmail の検索・閲覧・下書き作成を行うための Claude Code Skill です。

## 概要

このスキルは Google Apps Script (GAS) で構築された Web API を通じて、Gmail を操作します。メールの検索、閲覧、下書き作成が可能です。

**設計方針**: 送信機能は意図的に含めていません。下書きを作成し、人間が Gmail で確認してから送信する安全設計です。

## 環境設定

エンドポイントURLは、プロジェクトルートの `.env` ファイルに保存されています：

```bash
source .env
echo $GMAIL_ENDPOINT
```

`.env` ファイルがない場合は、`$CCSKILL_GMAIL_DIR/install.sh` を実行してセットアップしてください。

---

## curl 実行時の必須ルール

GAS Web App は特殊なリダイレクト処理を行うため、以下のルールを**必ず**守ってください。

### 1. GET/POST の使い分け（必須）

| 操作 | メソッド | 例 |
|------|---------|-----|
| search, get_thread, get_message, list_labels | GET | `?action=search&query=...` |
| create_draft | POST | `--data '{"action":"create_draft",...}'` |

### 2. タイムアウト設定（必須）

GAS はコールドスタート時に起動が遅くなります。**必ず `--max-time 60` を指定**：

```bash
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=list_labels"
```

### 3. POST リクエストの書式（必須）

**`--data` を使用**してください（`-X POST -d` は NG）：

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"example@gmail.com","subject":"件名","body":"本文"}' \
  "$GMAIL_ENDPOINT"
```

### 4. リダイレクト追跡（必須）

**`-L` オプションは必須**です。

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

### 書き込み (POST)

| アクション | 説明 | パラメータ |
|-----------|------|-----------|
| create_draft | 下書き作成 | `to`, `subject`, `body` (必須), `cc`, `bcc` (任意) |

→ 詳細: [reference/](reference/)

---

## Gmail 検索クエリ

`search` API は Gmail の検索構文をそのまま使用できます：

```bash
# 未読メール
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread"

# 特定の送信者から
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=from:boss@company.com"

# 件名に含む
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=$(echo -n 'subject:請求書' | jq -sRr @uri)"

# 日付指定
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=after:2024/01/01"

# 添付ファイル付き
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=has:attachment"

# 複合条件
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=$(echo -n 'is:unread from:important@example.com' | jq -sRr @uri)"
```

---

## curl コマンドテンプレート

```bash
# ヘルスチェック
curl -sL --max-time 60 "$GMAIL_ENDPOINT"

# メール検索
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=10"

# スレッド取得
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=THREAD_ID"

# メッセージ詳細
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_message&messageId=MESSAGE_ID"

# ラベル一覧
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=list_labels"

# 下書き作成
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"recipient@example.com","subject":"件名","body":"本文"}' \
  "$GMAIL_ENDPOINT"

# CC/BCC 付き下書き
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"to@example.com","cc":"cc@example.com","bcc":"bcc@example.com","subject":"件名","body":"本文"}' \
  "$GMAIL_ENDPOINT"
```

---

## レスポンス形式

**成功時:**
```json
{"ok": true, "data": {...}}
```

**エラー時:**
```json
{"ok": false, "error": "エラーメッセージ"}
```

---

## ワークフロー例

### 未読メールを確認して返信下書きを作成

```bash
source .env

# 1. 未読メール一覧を取得
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=5"

# 2. 特定のスレッドを詳細表示
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=19bf7f25b96ab637"

# 3. 返信下書きを作成
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"sender@example.com","subject":"Re: 元の件名","body":"ご連絡ありがとうございます。\n\n承知いたしました。"}' \
  "$GMAIL_ENDPOINT"

# 4. Gmail で下書きを確認・送信
# https://mail.google.com/mail/u/0/#drafts
```

---

## 制限事項

- **送信機能なし**: 下書き作成のみ（送信は Gmail UI で手動）
- **認証**: Web App は「全員がアクセス可能」で公開されている必要があります
- **レート制限**: GAS の実行時間制限（6分/実行）が適用されます
- **添付ファイル**: 現在は添付ファイルの追加・ダウンロードは未対応

---

## 関連ドキュメント

- [API リファレンス](reference/) - 全 API の詳細仕様
- [トラブルシューティング](troubleshooting.md) - よくある問題と解決策
- [ワークフロー例](examples.md) - 実践的な使用例
