# トラブルシューティング

Gmail Skill でよくある問題と解決策です。

> **推奨**: `.ccskill-gmail/api` スタンドアロンスクリプトを使用すると、`-L`、`--max-time 60`、`--data`、Bearer 認証が自動適用されるため、以下のトラブルの大半を回避できます。

---

## クイックリファレンス

| 症状 | 原因 | 解決策 |
|------|------|--------|
| HTML が返る（ログインページ） | 認証なし / トークン期限切れ | `clasp login` を実行 |
| タイムアウト | コールドスタート | 再試行（`--max-time 60` は自動適用済み） |
| Unknown action | GET/POST の使い分け誤り | get / post サブコマンドを正しく使用 |
| Invalid JSON | JSON 構文エラー | JSON を事前検証 |
| Thread/Message not found | ID の誤りまたは削除済み | `search` で最新の ID を取得 |
| 日本語検索が動かない | 直接 curl 使用時のエンコード漏れ | get サブコマンドを使用（自動エンコード） |
| エンドポイント未設定 | endpoint ファイルなし / install 未完了 | `ccskill-gmail update` を実行 |
| Action "xxx" is denied by permissions config | パーミッション設定で拒否 | `config.js` の `permissions.deny` から該当アクションを削除 |

---

## 詳細な解決策

### Action denied by permissions config

**症状**: `{"ok":false,"error":"Action \"move_to_trash\" is denied by permissions config. ..."}`

**原因**: `config.js` の `permissions.deny` にそのアクションが含まれている（`move_to_trash` はデフォルトで無効）

**解決策**:

1. インストール先の `config.js` を編集し、`permissions.deny` 配列から該当アクションを削除
2. 再デプロイ
   ```bash
   ccskill-gmail apply-config
   ```

**例**: `move_to_trash` を有効にする場合
```javascript
// Before
permissions: {
  deny: [
    'move_to_trash',
  ]
}

// After
permissions: {
  deny: [
    // 'move_to_trash',  // コメントアウトまたは削除
  ]
}
```

---

### 認証エラー (401 / アクセス拒否)

**症状**:
- レスポンスが HTML（Google ログインページ）
- `{"ok":false,"error":"Authorization required"}` のようなエラー

**原因と対処**:

1. **clasp にログインしていない**
   ```bash
   clasp login
   ```

2. **トークンが期限切れ（自動リフレッシュ失敗）**
   ```bash
   # ~/.clasprc.json を確認
   jq '.tokens.default.expiry_date' ~/.clasprc.json
   # 再ログイン
   clasp login
   ```

3. **デプロイが "Anyone" のまま**
   - GAS エディタでデプロイ設定を確認
   - 「自分のみ」(MYSELF) に変更して再デプロイ

4. **api スクリプトを使わずに直接 curl している**
   ```bash
   # NG: 直接 curl（Bearer トークンなし）
   curl -sL "https://script.google.com/.../exec?action=list_labels"

   # OK: api スクリプト経由（自動認証）
   .ccskill-gmail/api get action=list_labels
   ```

---

### タイムアウトエラー

**症状**: リクエストが応答なしでハングする

**原因**: GAS のコールドスタート（初回起動の遅延）

**解決策**: api スクリプトは内部で `--max-time 60` を設定済みです。それでもタイムアウトする場合は再試行してください。

```bash
# 再試行
.ccskill-gmail/api get action=list_labels
```

---

### Unknown action エラー

**症状**: `{"ok":false,"error":"Unknown action: search"}`

**原因**: GET/POST の使い分けが間違っている

**解決策**: 読み取り系は `get`、書き込み系は `post` サブコマンドを使用

```bash
# OK: get で search
.ccskill-gmail/api get action=search query="is:unread"

# NG: post で search を呼んでいる
.ccskill-gmail/api post '{"action":"search","query":"is:unread"}'
```

---

### Invalid JSON エラー

**症状**: `{"ok":false,"error":"Invalid JSON in request body"}`

**原因**: JSON の構文エラー（クォート、カンマ等）

**解決策**:
```bash
# JSON を事前に検証
echo '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}' | jq .

# シングルクォートで囲む（シェル変数展開を防ぐ）
.ccskill-gmail/api post '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}'
```

---

### Thread not found / Message not found

**症状**: `{"ok":false,"error":"Thread not found: xxx"}`

**原因**:
- スレッド/メッセージ ID が間違っている
- 該当メールが削除済み

**解決策**: `search` で最新の ID を取得し直す

```bash
.ccskill-gmail/api get action=search query="is:unread" maxResults=5
```

---

### 日本語検索の問題

**症状**: 日本語を含む検索が正しく動作しない

**以前の問題**: 日本語を URL エンコードする必要があった

**現在の対処**: get サブコマンドは値を自動的に URL エンコードするため、日本語をそのまま渡せます:

```bash
# OK: そのまま日本語を使える
.ccskill-gmail/api get action=search query="from:田中太郎"

# 手動エンコードは不要
```

---

### 権限エラー

**症状**: デプロイ時に権限エラー、または API 呼び出しで 403 エラー

**原因**: Gmail へのアクセス権限が承認されていない

**解決策**:
1. GAS エディタで「デプロイ」→「デプロイを管理」を開く
2. 「このアプリは確認されていません」画面で「詳細」→「安全でないページに移動」で承認

---

### エンドポイント未設定

**症状**: `{"ok":false,"error":"GMAIL_ENDPOINT not set..."}`

**原因**: `.ccskill-gmail/endpoint` ファイルが存在しない、または install/update が完了していない

**解決策**:
```bash
# update で endpoint ファイルを自動生成
ccskill-gmail update

# endpoint ファイルの内容を確認
cat .ccskill-gmail/endpoint
```

---

## デバッグ方法

### ヘルスチェック

```bash
.ccskill-gmail/api get
# 期待: {"ok":true,"data":{"status":"ok","message":"Gmail Skill is running","version":"1.0.0"}}
```

### トークン確認

```bash
# auth.sh を直接読み込んでトークンを確認（デバッグ用）
source .ccskill-gmail/auth.sh && gas_token
# アクセストークンが表示されれば OK
```

### エンドポイント確認

```bash
cat .ccskill-gmail/endpoint
# URL が表示されれば endpoint ファイルが正しく設定されている
```

### レスポンスの確認

```bash
# レスポンスを整形表示
.ccskill-gmail/api get action=list_labels | jq .
```
