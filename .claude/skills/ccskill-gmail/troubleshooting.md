# トラブルシューティング

Gmail Skill でよくある問題と解決策です。

> **推奨**: `source .ccskill-gmail/api.sh` を使用すると、`ccskill-get` / `ccskill-post` ラッパーが利用可能になります。これらのラッパーは `-L`、`--max-time 60`、`--data`、Bearer 認証を自動適用するため、以下のトラブルの大半を回避できます。

---

## クイックリファレンス

| 症状 | 原因 | 解決策 |
|------|------|--------|
| HTML が返る（ログインページ） | 認証なし / トークン期限切れ | `clasp login` を実行 |
| タイムアウト | コールドスタート | 再試行（`--max-time 60` は自動適用済み） |
| Unknown action | GET/POST の使い分け誤り | ccskill-get / ccskill-post を正しく使用 |
| Invalid JSON | JSON 構文エラー | JSON を事前検証 |
| Thread/Message not found | ID の誤りまたは削除済み | `search` で最新の ID を取得 |
| 日本語検索が動かない | 直接 curl 使用時のエンコード漏れ | ccskill-get を使用（自動エンコード） |
| `$GMAIL_ENDPOINT` が空 | api.sh 未読み込み / .env なし | `source .ccskill-gmail/api.sh` を実行 |

---

## 詳細な解決策

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

4. **api.sh を source していない**
   ```bash
   # NG: 直接 curl（Bearer トークンなし）
   curl -sL "$GMAIL_ENDPOINT?action=list_labels"

   # OK: api.sh 経由（自動認証）
   source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_labels
   ```

---

### タイムアウトエラー

**症状**: リクエストが応答なしでハングする

**原因**: GAS のコールドスタート（初回起動の遅延）

**解決策**: ccskill-get / ccskill-post は内部で `--max-time 60` を設定済みです。それでもタイムアウトする場合は再試行してください。

```bash
# 再試行
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_labels
```

---

### Unknown action エラー

**症状**: `{"ok":false,"error":"Unknown action: search"}`

**原因**: GET/POST の使い分けが間違っている

**解決策**: 読み取り系は `ccskill-get`、書き込み系は `ccskill-post` を使用

```bash
# OK: GET で search
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread"

# NG: POST で search を呼んでいる
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"search","query":"is:unread"}'
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
source .ccskill-gmail/api.sh && ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}'
```

---

### Thread not found / Message not found

**症状**: `{"ok":false,"error":"Thread not found: xxx"}`

**原因**:
- スレッド/メッセージ ID が間違っている
- 該当メールが削除済み

**解決策**: `search` で最新の ID を取得し直す

```bash
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread" maxResults=5
```

---

### 日本語検索の問題

**症状**: 日本語を含む検索が正しく動作しない

**以前の問題**: 日本語を URL エンコードする必要があった

**現在の対処**: ccskill-get は値を自動的に URL エンコードするため、日本語をそのまま渡せます:

```bash
# OK: そのまま日本語を使える
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=search query="from:田中太郎"

# 手動エンコードは不要
# curl ... "$(jq -sRr @uri <<< '田中太郎')"  # この書き方はもう不要
```

---

### 権限エラー

**症状**: デプロイ時に権限エラー、または API 呼び出しで 403 エラー

**原因**: Gmail へのアクセス権限が承認されていない

**解決策**:
1. GAS エディタで「デプロイ」→「デプロイを管理」を開く
2. 「このアプリは確認されていません」画面で「詳細」→「安全でないページに移動」で承認

---

### .env ファイルがない / $GMAIL_ENDPOINT が空

**症状**: `$GMAIL_ENDPOINT` が空

**原因**: install が完了していない、または api.sh を source していない

**解決策**:
```bash
# api.sh が .env を自動読み込みするので、まずこれを試す
source .ccskill-gmail/api.sh && echo "$GMAIL_ENDPOINT"

# .env 自体がない場合は再インストール
ccskill-gmail install
```

---

## デバッグ方法

### ヘルスチェック

```bash
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT"
# 期待: {"ok":true,"data":{"status":"ok","message":"Gmail Skill is running","version":"1.0.0"}}
```

### トークン確認

```bash
source .ccskill-gmail/api.sh && gas_token
# アクセストークンが表示されれば OK
```

### エンドポイント確認

```bash
source .ccskill-gmail/api.sh && echo "$GMAIL_ENDPOINT"
# URL が表示されれば .env が正しく読み込まれている
```

### レスポンスの確認

```bash
# レスポンスを整形表示
source .ccskill-gmail/api.sh && ccskill-get "$GMAIL_ENDPOINT" action=list_labels | jq .
```
