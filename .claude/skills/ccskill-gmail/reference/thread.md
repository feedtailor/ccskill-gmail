# archive / move_to_trash - スレッド操作

スレッドのアーカイブとゴミ箱移動を行います。

---

## archive - アーカイブ

スレッドを受信トレイからアーカイブします。メール自体は削除されず、「すべてのメール」で確認可能です。

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | アーカイブするスレッドの ID |

### 実行例

```bash
ccskill-post "$GMAIL_ENDPOINT" '{"action":"archive","threadId":"19bf7f25b96ab637"}'
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "archive",
    "message": "スレッドをアーカイブしました"
  }
}
```

### 注意事項

- アーカイブは受信トレイからの削除のみ（メール自体は残る）
- 「すべてのメール」で確認可能
- ラベルは維持される

---

## move_to_trash - ゴミ箱に移動

スレッドをゴミ箱に移動します。30日後に自動削除されます。

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | ゴミ箱に移動するスレッドの ID |

### 実行例

```bash
ccskill-post "$GMAIL_ENDPOINT" '{"action":"move_to_trash","threadId":"19bf7f25b96ab637"}'
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "move_to_trash",
    "message": "スレッドをゴミ箱に移動しました"
  }
}
```

### 注意事項

- ゴミ箱のメールは 30 日後に自動削除
- ゴミ箱から復元可能
- 永久削除 API は安全のため提供していません

---

## ワークフロー例

### メール処理完全ワークフロー

```bash
source .ccskill-gmail/api.sh

# 1. 未読メールを検索
THREAD_ID=$(ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=1 | jq -r '.data.threads[0].id')

# 2. 内容を確認
ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId="$THREAD_ID" | jq '.data.subject'

# 3. 返信下書きを作成
ccskill-post "$GMAIL_ENDPOINT" "{\"action\":\"create_reply_draft\",\"threadId\":\"$THREAD_ID\",\"body\":\"承知いたしました。\"}"

# 4. 既読にしてラベル追加
ccskill-post "$GMAIL_ENDPOINT" "{\"action\":\"mark_read\",\"threadId\":\"$THREAD_ID\"}"
ccskill-post "$GMAIL_ENDPOINT" "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"対応済\"}"

# 5. アーカイブして受信トレイを整理
ccskill-post "$GMAIL_ENDPOINT" "{\"action\":\"archive\",\"threadId\":\"$THREAD_ID\"}"
```
