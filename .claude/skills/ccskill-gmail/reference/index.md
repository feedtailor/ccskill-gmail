# Gmail Skill API リファレンス

## Phase 1 API

### 読み取り系 (GET)

| API | ファイル | 説明 |
|-----|---------|------|
| search | [search.md](search.md) | メール検索 |
| get_thread | [read.md](read.md) | スレッド取得 |
| get_message | [read.md](read.md) | メッセージ詳細 |
| list_labels | [read.md](read.md) | ラベル一覧 |

### 書き込み系 (POST)

| API | ファイル | 説明 |
|-----|---------|------|
| create_draft | [draft.md](draft.md) | 下書き作成 |

---

## 今後追加予定 (Phase 2+)

| API | 説明 |
|-----|------|
| create_reply_draft | 返信下書き作成 |
| mark_read / mark_unread | 既読/未読操作 |
| add_label / remove_label | ラベル操作 |
| archive | アーカイブ |
| move_to_trash | ゴミ箱へ移動 |
