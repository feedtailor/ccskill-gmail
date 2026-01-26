# トラブルシューティング

## よくある問題と解決策

### 1. タイムアウトエラー

**症状**: curl がタイムアウトする

**原因**: GAS のコールドスタート（初回起動が遅い）

**解決策**: `--max-time 60` を指定する

```bash
# 正しい
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=list_labels"

# NG: タイムアウトが短すぎる
curl -sL "$GMAIL_ENDPOINT?action=list_labels"
```

---

### 2. Unknown action エラー

**症状**: `{"ok":false,"error":"Unknown action: search"}`

**原因**: POST で GET 用の API を呼んでいる

**解決策**: GET/POST を正しく使い分ける

```bash
# 正しい（GET）
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread"

# NG: POST で search を呼んでいる
curl -sL --max-time 60 --data '{"action":"search","query":"is:unread"}' "$GMAIL_ENDPOINT"
```

---

### 3. Invalid JSON エラー

**症状**: `{"ok":false,"error":"Invalid JSON in request body"}`

**原因**:
- JSON の構文エラー
- `-X POST -d` の組み合わせ（リダイレクト時に POST が GET に変わる）

**解決策**: `--data` を使用する

```bash
# 正しい
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}' \
  "$GMAIL_ENDPOINT"

# NG: -X POST -d の組み合わせ
curl -sL --max-time 60 -X POST -d '...' "$GMAIL_ENDPOINT"
```

---

### 4. Thread not found / Message not found

**症状**: `{"ok":false,"error":"Thread not found: xxx"}`

**原因**:
- スレッド/メッセージ ID が間違っている
- 該当メールが削除済み

**解決策**: `search` で最新の ID を取得し直す

```bash
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=5"
```

---

### 5. 日本語クエリが動作しない

**症状**: 日本語を含む検索が正しく動作しない

**原因**: URL エンコードされていない

**解決策**: `jq` で URL エンコード

```bash
# 正しい
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=$(echo -n 'subject:請求書' | jq -sRr @uri)"

# NG: エンコードなし
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=search&query=subject:請求書"
```

---

### 6. 権限エラー

**症状**: デプロイ時に権限エラー、または API 呼び出しで 403 エラー

**原因**:
- Gmail へのアクセス権限が承認されていない
- Web App のアクセス設定が「自分のみ」になっている

**解決策**:
1. GAS エディタで「デプロイ」→「デプロイを管理」を開く
2. アクセスできるユーザーが「全員」になっているか確認
3. 「このアプリは確認されていません」画面で「詳細」→「安全でないページに移動」で承認

---

### 7. .env ファイルがない

**症状**: `$GMAIL_ENDPOINT` が空

**原因**: install.sh が完了していない

**解決策**:
```bash
# 手動で .env を作成
cat > .env << 'EOF'
GMAIL_ENDPOINT=https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec
EOF

# 読み込み
source .env
```

---

## デバッグ方法

### レスポンスの確認

```bash
# レスポンスを整形表示
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=list_labels" | jq .
```

### ヘルスチェック

```bash
# API が動作しているか確認
curl -sL --max-time 60 "$GMAIL_ENDPOINT"
# 期待: {"ok":true,"data":{"status":"ok","message":"Gmail Skill is running","version":"1.0.0"}}
```
