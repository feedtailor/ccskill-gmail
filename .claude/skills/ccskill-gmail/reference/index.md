# Gmail Skill API リファレンス

## 前提

`.ccskill-gmail/api` はスタンドアロンスクリプトです。エンドポイントと認証はスクリプト内部で自動解決されます。

## 読み取り系 (GET)

| API | ファイル | 実行例 |
|-----|---------|--------|
| search | [search.md](search.md) | `.ccskill-gmail/api get action=search query="is:unread"` |
| get_thread | [read.md](read.md) | `.ccskill-gmail/api get action=get_thread threadId=ID` |
| get_message | [read.md](read.md) | `.ccskill-gmail/api get action=get_message messageId=ID` |
| list_labels | [read.md](read.md) | `.ccskill-gmail/api get action=list_labels` |
| get_unread_count | [read.md](read.md) | `.ccskill-gmail/api get action=get_unread_count` |

## 書き込み系 (POST)

| API | ファイル | 説明 |
|-----|---------|------|
| create_draft | [draft.md](draft.md) | 新規メールの下書き作成 |
| create_reply_draft | [draft.md](draft.md) | 既存スレッドへの返信下書き作成 |
| update_draft | [draft.md](draft.md) | 下書き更新 |
| delete_draft | [draft.md](draft.md) | 下書き削除 |
| mark_read | [status.md](status.md) | 既読にする |
| mark_unread | [status.md](status.md) | 未読にする |
| add_label | [label.md](label.md) | ラベル追加 |
| remove_label | [label.md](label.md) | ラベル削除 |
| archive | [thread.md](thread.md) | アーカイブ |
| move_to_trash | [thread.md](thread.md) | ゴミ箱へ移動 |
