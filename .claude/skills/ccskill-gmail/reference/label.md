# add_label / remove_label - ラベル操作

スレッドにラベルを追加・削除します。

---

## add_label - ラベル追加

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | スレッド ID |
| label | ✓ | ラベル名 |

### リクエスト例

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"add_label","threadId":"19bf7f25b96ab637","label":"対応済"}' \
  "$GMAIL_ENDPOINT"
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "label": "対応済",
    "action": "add_label",
    "message": "ラベル「対応済」を追加しました"
  }
}
```

### 注意事項

- 存在しないラベルを指定した場合は**自動的に新規作成**されます
- ネストしたラベルは `親ラベル/子ラベル` 形式で指定できます

---

## remove_label - ラベル削除

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | スレッド ID |
| label | ✓ | ラベル名 |

### リクエスト例

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"remove_label","threadId":"19bf7f25b96ab637","label":"対応済"}' \
  "$GMAIL_ENDPOINT"
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "label": "対応済",
    "action": "remove_label",
    "message": "ラベル「対応済」を削除しました"
  }
}
```

### エラー例

存在しないラベルを削除しようとした場合：

```json
{
  "ok": false,
  "error": "Label not found: 存在しないラベル"
}
```

---

## ワークフロー例

```bash
source .env

# 1. 未読メールを検索
THREAD_ID=$(curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=1" | jq -r '.data.threads[0].id')

# 2. 「要確認」ラベルを追加
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"要確認\"}" \
  "$GMAIL_ENDPOINT"

# 3. 対応後、「要確認」を外して「対応済」を追加
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"remove_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"要確認\"}" \
  "$GMAIL_ENDPOINT"

curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"対応済\"}" \
  "$GMAIL_ENDPOINT"
```

---

## 制限事項

- **スレッド単位での操作のみ対応**: 個別メッセージへのラベル付与は GmailApp の制限により未対応
- **システムラベル**: `INBOX`, `SENT`, `TRASH` などのシステムラベルは操作できません
