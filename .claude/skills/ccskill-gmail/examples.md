# ワークフロー例

## 1. 未読メールの確認

```bash
source .env

# 未読メール一覧を取得
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=10" | jq .

# 特定のスレッドを詳細表示
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=THREAD_ID" | jq .
```

---

## 2. 重要な送信者からのメールを確認

```bash
source .env

# 特定の送信者からの未読メール
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=$(echo -n 'is:unread from:boss@company.com' | jq -sRr @uri)" | jq .
```

---

## 3. 返信下書きを作成

```bash
source .env

# 1. 未読メールを検索
RESULT=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=1")
echo "$RESULT" | jq .

# 2. スレッドの詳細を取得
THREAD_ID=$(echo "$RESULT" | jq -r '.data.threads[0].id')
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=$THREAD_ID" | jq .

# 3. 返信下書きを作成（宛先・件名は自動設定）
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{
    \"action\": \"create_reply_draft\",
    \"threadId\": \"$THREAD_ID\",
    \"body\": \"ご連絡ありがとうございます。\\n\\n承知いたしました。対応いたします。\\n\\nよろしくお願いいたします。\"
  }" \
  "$GMAIL_ENDPOINT" | jq .

# 4. Gmail で下書きを確認・送信
echo "https://mail.google.com/mail/u/0/#drafts"
```

---

## 4. 添付ファイル付きメールを検索

```bash
source .env

# 添付ファイル付きの未読メール
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=$(echo -n 'is:unread has:attachment' | jq -sRr @uri)" | jq .
```

---

## 5. 日付範囲でメールを検索

```bash
source .env

# 今月のメール
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=after:2024/01/01%20before:2024/02/01" | jq .

# 過去7日間
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=newer_than:7d" | jq .
```

---

## 6. ラベル別にメールを確認

```bash
source .env

# ラベル一覧を取得
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=list_labels" | jq '.data.labels[] | select(.unreadCount > 0)'

# 特定ラベルのメール
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=$(echo -n 'label:Projects is:unread' | jq -sRr @uri)" | jq .
```

---

## 7. 複数宛先への下書き作成

```bash
source .env

# チームメンバー全員への連絡
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{
    "action": "create_draft",
    "to": "member1@example.com,member2@example.com,member3@example.com",
    "cc": "manager@example.com",
    "subject": "週次ミーティングのお知らせ",
    "body": "お疲れ様です。\n\n週次ミーティングを以下の日程で行います。\n\n日時: 1月30日（火）15:00〜\n場所: 会議室A\n\nご参加よろしくお願いいたします。"
  }' \
  "$GMAIL_ENDPOINT" | jq .
```

---

## 8. メールを読んで既読にする

```bash
source .env

# 1. 未読メールを取得
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=1" | jq -r '.data.threads[0].id')

# 2. 内容を確認
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=$THREAD_ID" | jq '.data.subject, .data.messages[-1].body'

# 3. 既読にする
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"mark_read\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT" | jq .
```

---

## 9. メールにラベルを付けて整理

```bash
source .env

# 1. 未読の重要メールを検索
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread%20is:important&maxResults=1" | jq -r '.data.threads[0].id')

# 2. 「要対応」ラベルを追加
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"要対応\"}" \
  "$GMAIL_ENDPOINT" | jq .

# 3. 対応完了後、ラベルを変更
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"remove_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"要対応\"}" \
  "$GMAIL_ENDPOINT"

curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"対応済\"}" \
  "$GMAIL_ENDPOINT" | jq .
```

---

## 10. 未読メール対応ワークフロー（完全版）

```bash
source .env

# 1. 未読メールを検索
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=1" | jq -r '.data.threads[0].id')

# 2. スレッドの内容を確認
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=$THREAD_ID" | jq '.data.subject, .data.messages[-1].body'

# 3. 返信下書きを作成
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"create_reply_draft\",\"threadId\":\"$THREAD_ID\",\"body\":\"承知いたしました。\"}" \
  "$GMAIL_ENDPOINT" | jq .

# 4. 既読にする
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"mark_read\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT"

# 5. ラベルを追加
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"対応済\"}" \
  "$GMAIL_ENDPOINT" | jq .

# 6. Gmail で下書きを確認・送信
echo "https://mail.google.com/mail/u/0/#drafts"
```

---

## 11. 未読数の監視

```bash
source .env

# 受信トレイの未読数
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_unread_count" | jq .

# 特定ラベルの未読数
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_unread_count&label=重要" | jq .
```

---

## 12. メール処理後のアーカイブ

```bash
source .env

# 1. 未読メールを処理
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=1" | jq -r '.data.threads[0].id')

# 2. 既読にしてラベル追加
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"mark_read\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT"

curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"対応済\"}" \
  "$GMAIL_ENDPOINT"

# 3. アーカイブして受信トレイを整理
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"archive\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT" | jq .
```

---

## 13. 不要メールの削除

```bash
source .env

# 1. 古いプロモーションメールを検索
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=category:promotions%20older_than:30d&maxResults=1" | jq -r '.data.threads[0].id')

# 2. ゴミ箱に移動（30日後に自動削除）
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"move_to_trash\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT" | jq .
```

---

## 14. 完全ワークフロー（未読確認→返信→整理→アーカイブ）

```bash
source .env

# 1. 未読数を確認
echo "=== 未読数確認 ==="
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_unread_count" | jq '.data.unreadCount'

# 2. 未読メールを取得
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=1" | jq -r '.data.threads[0].id')

# 3. 内容を確認
echo "=== メール内容 ==="
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=$THREAD_ID" | jq '.data.subject, .data.messages[-1].body'

# 4. 返信下書きを作成
echo "=== 返信下書き作成 ==="
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"create_reply_draft\",\"threadId\":\"$THREAD_ID\",\"body\":\"承知いたしました。\"}" \
  "$GMAIL_ENDPOINT" | jq '.data.draftId'

# 5. 既読にする
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"mark_read\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT" > /dev/null

# 6. ラベルを追加
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"対応済\"}" \
  "$GMAIL_ENDPOINT" > /dev/null

# 7. アーカイブ
echo "=== アーカイブ ==="
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"archive\",\"threadId\":\"$THREAD_ID\"}" \
  "$GMAIL_ENDPOINT" | jq '.data.message'

# 8. 未読数を再確認
echo "=== 処理後の未読数 ==="
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_unread_count" | jq '.data.unreadCount'

echo "Gmail で下書きを確認・送信: https://mail.google.com/mail/u/0/#drafts"
```
