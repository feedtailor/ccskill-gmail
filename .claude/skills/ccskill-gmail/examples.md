# ワークフロー例

## 前提

すべての例は、最初に以下を実行済みであることを前提とします:

```bash
source .ccskill-gmail/api.sh
```

これにより `$GMAIL_ENDPOINT`、`ccskill-get`、`ccskill-post` が使用可能になります。

**重要: Claude Code の Bash ツールは呼び出しごとに別プロセスで実行されるため、`source` と `ccskill-get` / `ccskill-post` は必ず `&&` で繋いで同一コマンドとして実行してください。**

---

## 1. 未読メールの確認

```bash
# 未読メール一覧を取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=10

# 特定のスレッドを詳細表示
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=THREAD_ID
```

---

## 2. 重要な送信者からのメールを確認

```bash
# 特定の送信者からの未読メール
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread from:boss@company.com"
```

---

## 3. 返信下書きを作成

```bash
# 1. 未読メールを検索
source .ccskill-gmail/api.sh && RESULT=$(ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=1) && echo "$RESULT" | jq .

# 2. スレッドの詳細を取得（THREAD_ID は手順1の結果から取得）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=THREAD_ID

# 3. 返信下書きを作成（宛先・件名は自動設定）
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"ご連絡ありがとうございます。\n\n承知いたしました。対応いたします。\n\nよろしくお願いいたします。"}'

# 4. Gmail で下書きを確認・送信
# https://mail.google.com/mail/u/0/#drafts
```

---

## 4. 添付ファイル付きメールを検索・ダウンロード

```bash
# 添付ファイル付きの未読メール
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread has:attachment"

# 添付ファイル一覧を確認（MESSAGE_ID は上の結果から取得）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_attachments messageId=MESSAGE_ID

# 添付ファイルをダウンロード（index=0 の添付ファイル）
source .ccskill-gmail/api.sh && ccskill-download "$GMAIL_ENDPOINT" MESSAGE_ID 0 /tmp/attachment.pdf
```

---

## 5. メール本文を HTML で取得・PDF 化

```bash
# メール本文を HTML で保存（ヘッダー付き）
source .ccskill-gmail/api.sh && ccskill-save-html "$GMAIL_ENDPOINT" MESSAGE_ID /tmp/email.html

# ヘッダーなしで保存
source .ccskill-gmail/api.sh && ccskill-save-html "$GMAIL_ENDPOINT" MESSAGE_ID /tmp/email.html false

# PDF に変換（wkhtmltopdf がある場合）
wkhtmltopdf /tmp/email.html /tmp/email.pdf

# PDF に変換（Chrome headless の場合）
google-chrome --headless --print-to-pdf=/tmp/email.pdf /tmp/email.html
```

PDF 変換ツールがない場合は、HTML ファイルをブラウザで開いて「印刷 > PDF として保存」を案内してください。

---

## 6. 日付範囲でメールを検索

```bash
# 今月のメール
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="after:2024/01/01 before:2024/02/01"

# 過去7日間
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="newer_than:7d"
```

---

## 7. ラベル別にメールを確認

```bash
# ラベル一覧を取得
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_labels | jq '.data.labels[] | select(.unreadCount > 0)'

# 特定ラベルのメール
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="label:Projects is:unread"
```

---

## 8. 複数宛先への下書き作成

```bash
# チームメンバー全員への連絡
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"member1@example.com,member2@example.com,member3@example.com","cc":"manager@example.com","subject":"週次ミーティングのお知らせ","body":"お疲れ様です。\n\n週次ミーティングを以下の日程で行います。\n\n日時: 1月30日（火）15:00〜\n場所: 会議室A\n\nご参加よろしくお願いいたします。"}'
```

長い JSON の場合は Write ツール + `@file` パターンを使用:

```
# Step 1: Write ツールで JSON ファイルを作成
Write("/tmp/draft.json") に以下の内容:
{"action":"create_draft","to":"member1@example.com,member2@example.com","cc":"manager@example.com","subject":"週次ミーティングのお知らせ","body":"お疲れ様です。\n\n...長い本文..."}
```

```bash
# Step 2: Bash で送信
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" @/tmp/draft.json
```

---

## 9. メールを読んで既読にする

```bash
# 1. 未読メールを取得（THREAD_ID を確認）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=1

# 2. 内容を確認
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. 既読にする
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","threadId":"THREAD_ID"}'
```

---

## 10. メールにラベルを付けて整理

```bash
# 1. 未読の重要メールを検索（THREAD_ID を確認）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread is:important" maxResults=1

# 2. 「要対応」ラベルを追加
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"add_label","threadId":"THREAD_ID","label":"要対応"}'

# 3. 対応完了後、ラベルを変更
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"remove_label","threadId":"THREAD_ID","label":"要対応"}'
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'
```

---

## 11. 未読メール対応ワークフロー（完全版）

```bash
# 1. 未読メールを検索（THREAD_ID を確認）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=1

# 2. スレッドの内容を確認
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. 返信下書きを作成
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 4. 既読にする
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","threadId":"THREAD_ID"}'

# 5. ラベルを追加
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 6. Gmail で下書きを確認・送信
# https://mail.google.com/mail/u/0/#drafts
```

---

## 12. 未読数の監視

```bash
# 受信トレイの未読数
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count

# 特定ラベルの未読数
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count label=重要
```

---

## 13. メール処理後のアーカイブ

```bash
# 1. 未読メールを処理（THREAD_ID を確認）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=1

# 2. 既読にしてラベル追加
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","threadId":"THREAD_ID"}'
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 3. アーカイブして受信トレイを整理
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"archive","threadId":"THREAD_ID"}'
```

---

## 14. 不要メールの削除

```bash
# 1. 古いプロモーションメールを検索（THREAD_ID を確認）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="category:promotions older_than:30d" maxResults=1

# 2. ゴミ箱に移動（30日後に自動削除）
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"move_to_trash","threadId":"THREAD_ID"}'
```

---

## 15. 完全ワークフロー（未読確認 → 返信 → 整理 → アーカイブ）

```bash
# 1. 未読数を確認
source .ccskill-gmail/api.sh && echo "=== 未読数確認 ===" && ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count | jq '.data.unreadCount'

# 2. 未読メールを取得（THREAD_ID を確認）
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=1

# 3. 内容を確認
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 4. 返信下書きを作成
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 5. 既読にする
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","threadId":"THREAD_ID"}'

# 6. ラベルを追加
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 7. アーカイブ
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"archive","threadId":"THREAD_ID"}'

# 8. 未読数を再確認
source .ccskill-gmail/api.sh && echo "=== 処理後の未読数 ===" && ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count | jq '.data.unreadCount'

# Gmail で下書きを確認・送信: https://mail.google.com/mail/u/0/#drafts
```
