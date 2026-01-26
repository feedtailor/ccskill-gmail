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

# 3. 返信下書きを作成
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{
    "action": "create_draft",
    "to": "sender@example.com",
    "subject": "Re: 元の件名",
    "body": "ご連絡ありがとうございます。\n\n承知いたしました。対応いたします。\n\nよろしくお願いいたします。"
  }' \
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
