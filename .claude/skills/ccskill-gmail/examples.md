# ワークフロー例

## 前提

以下のワークフロー例では `.ccskill-gmail/api` コマンドを使用します。
エンドポイントと認証はスクリプト内部で自動解決されます。

---

## 1. 未読メールの確認

```bash
# 未読メール一覧を取得
.ccskill-gmail/api get action=search query="is:unread" maxResults=10

# 特定のスレッドを詳細表示
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID
```

---

## 2. 重要な送信者からのメールを確認

```bash
# 特定の送信者からの未読メール
.ccskill-gmail/api get action=search query="is:unread from:boss@company.com"
```

---

## 3. 返信下書きを作成

```bash
# 1. 未読メールを検索
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. スレッドの詳細を取得（THREAD_ID は手順1の結果から取得）
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID

# 3. 返信下書きを作成（宛先・件名は自動設定、デフォルトで全員に返信）
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"ご連絡ありがとうございます。\n\n承知いたしました。対応いたします。\n\nよろしくお願いいたします。"}'

# 送信者のみに返信したい場合（replyAll: false）
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。","replyAll":false}'

# 自分の送信メッセージをスキップせず、最後のメッセージに返信したい場合
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"追記です。","skipSelf":false,"replyAll":false}'

# 4. Gmail で下書きを確認・送信
# https://mail.google.com/mail/u/0/#drafts
```

デフォルト動作（`skipSelf: true`, `replyAll: true`）は、自分が最後に返信したスレッドでも正しく相手に宛てた全員返信の下書きを作成します。

---

## 4. 添付ファイル付きメールを検索・ダウンロード

```bash
# 添付ファイル付きの未読メール
.ccskill-gmail/api get action=search query="is:unread has:attachment"

# 添付ファイル一覧を確認（MESSAGE_ID は上の結果から取得）
.ccskill-gmail/api get action=list_attachments messageId=MESSAGE_ID

# 添付ファイルをダウンロード（index=0 の添付ファイル）
.ccskill-gmail/api download MESSAGE_ID 0 /tmp/attachment.pdf
```

---

## 5. メールを PDF 化（印刷）

```bash
# メールを PDF として保存（HTML取得 → PDF変換を一括実行）
.ccskill-gmail/api save-pdf MESSAGE_ID ./receipt.pdf

# HTML として保存したい場合
.ccskill-gmail/api save-html MESSAGE_ID ./email.html
```

`save-pdf` は Chrome headless / wkhtmltopdf を自動検出します。ツールがない場合は HTML を保存し、ブラウザでの印刷手順を案内します。

---

## 6. 日付範囲でメールを検索

```bash
# 今月のメール
.ccskill-gmail/api get action=search query="after:2024/01/01 before:2024/02/01"

# 過去7日間
.ccskill-gmail/api get action=search query="newer_than:7d"
```

---

## 7. ラベル別にメールを確認

```bash
# ラベル一覧を取得
.ccskill-gmail/api get action=list_labels | jq '.data.labels[] | select(.unreadCount > 0)'

# 特定ラベルのメール
.ccskill-gmail/api get action=search query="label:Projects is:unread"
```

---

## 8. 複数宛先への下書き作成

```bash
# チームメンバー全員への連絡
.ccskill-gmail/api post '{"action":"create_draft","to":"member1@example.com,member2@example.com,member3@example.com","cc":"manager@example.com","subject":"週次ミーティングのお知らせ","body":"お疲れ様です。\n\n週次ミーティングを以下の日程で行います。\n\n日時: 1月30日（火）15:00〜\n場所: 会議室A\n\nご参加よろしくお願いいたします。"}'
```

長い JSON の場合は Write ツール + `@file` パターンを使用:

```
# Step 1: Write ツールで JSON ファイルを作成
Write("/tmp/draft.json") に以下の内容:
{"action":"create_draft","to":"member1@example.com,member2@example.com","cc":"manager@example.com","subject":"週次ミーティングのお知らせ","body":"お疲れ様です。\n\n...長い本文..."}
```

```bash
# Step 2: Bash で送信
.ccskill-gmail/api post @/tmp/draft.json
```

---

## 9. メールを読んで既読にする

```bash
# 1. 未読メールを取得（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. 内容を確認
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. 既読にする
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'
```

---

## 10. メールにラベルを付けて整理

```bash
# 1. 未読の重要メールを検索（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="is:unread is:important" maxResults=1

# 2. 「要対応」ラベルを追加
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"要対応"}'

# 3. 対応完了後、ラベルを変更
.ccskill-gmail/api post '{"action":"remove_label","threadId":"THREAD_ID","label":"要対応"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'
```

---

## 11. 未読メール対応ワークフロー（完全版）

```bash
# 1. 未読メールを検索（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. スレッドの内容を確認
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. 返信下書きを作成
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 4. 既読にする
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 5. ラベルを追加
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 6. Gmail で下書きを確認・送信
# https://mail.google.com/mail/u/0/#drafts
```

---

## 12. 未読数の監視

```bash
# 受信トレイの未読数
.ccskill-gmail/api get action=get_unread_count

# 特定ラベルの未読数
.ccskill-gmail/api get action=get_unread_count label=重要
```

---

## 13. メール処理後のアーカイブ

```bash
# 1. 未読メールを処理（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. 既読にしてラベル追加
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 3. アーカイブして受信トレイを整理
.ccskill-gmail/api post '{"action":"archive","threadId":"THREAD_ID"}'
```

---

## 14. 不要メールの削除

```bash
# 1. 古いプロモーションメールを検索（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="category:promotions older_than:30d" maxResults=1

# 2. ゴミ箱に移動（30日後に自動削除）
.ccskill-gmail/api post '{"action":"move_to_trash","threadId":"THREAD_ID"}'
```

---

## 15. 完全ワークフロー（未読確認 → 返信 → 整理 → アーカイブ）

```bash
# 1. 未読数を確認
.ccskill-gmail/api get action=get_unread_count | jq '.data.unreadCount'

# 2. 未読メールを取得（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 3. 内容を確認
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 4. 返信下書きを作成
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 5. 既読にする
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 6. ラベルを追加
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 7. アーカイブ
.ccskill-gmail/api post '{"action":"archive","threadId":"THREAD_ID"}'

# 8. 未読数を再確認
.ccskill-gmail/api get action=get_unread_count | jq '.data.unreadCount'

# Gmail で下書きを確認・送信: https://mail.google.com/mail/u/0/#drafts
```

---

## 16. 添付ファイル付き下書き作成

添付ファイル付きの下書きは JSON が大きくなるため、Write ツール + `@file` パターンを使用します。

```
# Step 1: Write ツールで JSON ファイルを作成（base64 エンコード済みの content を含む）
Write("/tmp/draft-with-attachment.json") に以下の内容:
{
  "action": "create_draft",
  "to": "recipient@example.com",
  "subject": "報告書送付",
  "body": "お世話になっております。報告書を添付いたします。",
  "attachments": [
    {
      "filename": "report.pdf",
      "contentType": "application/pdf",
      "content": "JVBERi0xLjQ..."
    }
  ]
}
```

```bash
# Step 2: Bash で送信
.ccskill-gmail/api post @/tmp/draft-with-attachment.json
```

- `attachments` は配列で複数ファイルを添付可能
- `content` は base64 エンコード済みのデータ
- 合計サイズ上限: 5MB（base64 デコード後）
- `contentType` 省略時は `application/octet-stream`
