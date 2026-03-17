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
.ccskill-gmail/api post '{"action":"archive","threadId":"19bf7f25b96ab637"}'
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

> **注意**: このアクションはデフォルトで無効化されています（`permissions.deny` に含まれています）。有効にするには `config.js` の `permissions.deny` 配列から `'move_to_trash'` を削除し、`ccskill-gmail apply-config` を実行してください。

スレッドをゴミ箱に移動します。30日後に自動削除されます。

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | ゴミ箱に移動するスレッドの ID |

### 実行例

```bash
.ccskill-gmail/api post '{"action":"move_to_trash","threadId":"19bf7f25b96ab637"}'
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
# 1. 未読メールを検索（THREAD_ID を確認）
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. 内容を確認（THREAD_ID は手順1の結果から取得）
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject'

# 3. 返信下書きを作成
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 4. 既読にしてラベル追加
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 5. アーカイブして受信トレイを整理
.ccskill-gmail/api post '{"action":"archive","threadId":"THREAD_ID"}'
```
