# create_draft - 下書き作成

新しいメールの下書きを作成します。

## 設計思想

**送信機能は意図的に含めていません。**

- 誤送信防止: AI が直接送信すると取り消し不可
- 確認フロー: 人間が Gmail UI で内容確認 → 送信
- 責任の明確化: 送信は人間の意思決定

下書きは Gmail の「下書き」フォルダに保存され、ブラウザや Gmail アプリで確認・編集・送信できます。

---

## リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| to | ✓ | 宛先メールアドレス（カンマ区切りで複数可） |
| subject | ✓ | 件名 |
| body | ✓ | 本文（プレーンテキスト） |
| cc | | CC（カンマ区切りで複数可） |
| bcc | | BCC（カンマ区切りで複数可） |

---

## リクエスト例

### 基本的な下書き

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"recipient@example.com","subject":"お見積りの件","body":"お世話になっております。\n\n添付の通りお見積りをお送りします。\n\nよろしくお願いいたします。"}' \
  "$GMAIL_ENDPOINT"
```

### CC/BCC 付き

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"client@example.com","cc":"manager@example.com","bcc":"archive@example.com","subject":"プロジェクト進捗報告","body":"お疲れ様です。\n\n進捗をご報告します。"}' \
  "$GMAIL_ENDPOINT"
```

### 複数宛先

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"user1@example.com,user2@example.com","subject":"チームミーティングのお知らせ","body":"明日10時からミーティングを行います。"}' \
  "$GMAIL_ENDPOINT"
```

---

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "draftId": "r-935971606264660525",
    "to": "recipient@example.com",
    "subject": "お見積りの件",
    "message": "下書きを作成しました。Gmail で確認・送信してください。",
    "gmailUrl": "https://mail.google.com/mail/u/0/#drafts"
  }
}
```

---

## 下書きの確認・送信

1. Gmail を開く: https://mail.google.com/mail/u/0/#drafts
2. 下書き一覧から該当メールを選択
3. 内容を確認・編集
4. 「送信」ボタンをクリック

---

## 今後の拡張予定 (Phase 2+)

| API | 説明 |
|-----|------|
| create_reply_draft | 既存スレッドへの返信下書き |
| update_draft | 下書きの編集 |
| delete_draft | 下書きの削除 |
