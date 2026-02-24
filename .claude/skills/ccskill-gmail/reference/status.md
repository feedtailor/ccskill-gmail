# mark_read / mark_unread - 既読・未読操作

スレッドまたはメッセージの既読・未読状態を変更します。

---

## mark_read - 既読にする

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ※ | スレッド ID（threadId または messageId のいずれか必須） |
| messageId | ※ | メッセージ ID |

### 実行例

```bash
# スレッド全体を既読に
ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","threadId":"19bf7f25b96ab637"}'

# 特定のメッセージを既読に
ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_read","messageId":"19bf7f25b96ab637"}'
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "mark_read",
    "message": "スレッドを既読にしました"
  }
}
```

---

## mark_unread - 未読にする

### リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ※ | スレッド ID（threadId または messageId のいずれか必須） |
| messageId | ※ | メッセージ ID |

### 実行例

```bash
# スレッド全体を未読に
ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_unread","threadId":"19bf7f25b96ab637"}'

# 特定のメッセージを未読に
ccskill-post "$GMAIL_ENDPOINT" '{"action":"mark_unread","messageId":"19bf7f25b96ab637"}'
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "mark_unread",
    "message": "スレッドを未読にしました"
  }
}
```

---

## 使い分け

| 対象 | 効果 |
|------|------|
| threadId | スレッド内の全メッセージの既読/未読状態を変更 |
| messageId | 指定したメッセージのみの既読/未読状態を変更 |

両方指定された場合は `threadId` が優先されます。
