# Gmail Skill API リファレンス

## 読み取り系 (GET)

| API | ファイル | 説明 |
|-----|---------|------|
| search | [search.md](search.md) | メール検索 |
| get_thread | [read.md](read.md) | スレッド取得 |
| get_message | [read.md](read.md) | メッセージ詳細 |
| list_labels | [read.md](read.md) | ラベル一覧 |

## 書き込み系 (POST)

| API | ファイル | 説明 |
|-----|---------|------|
| create_draft | [draft.md](draft.md) | 新規メールの下書き作成 |
| create_reply_draft | [draft.md](draft.md) | 既存スレッドへの返信下書き作成 |
| mark_read | [status.md](status.md) | 既読にする |
| mark_unread | [status.md](status.md) | 未読にする |
| add_label | [label.md](label.md) | ラベル追加 |
| remove_label | [label.md](label.md) | ラベル削除 |

---

## 今後追加予定

| API | 説明 |
|-----|------|
| archive | アーカイブ |
| move_to_trash | ゴミ箱へ移動 |
