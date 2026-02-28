# MCP との差別化戦略

作成日: 2026-02-28

## 背景

Claude Code が標準 Gmail MCP（beta）を搭載。基本6機能（search, read_message, read_thread, list_drafts, create_draft, get_profile）を提供。
ccskill-gmail は19機能で完全上位互換だが、MCP 拡充に伴い差が縮まる可能性がある。
→ ccskill-gmail ならではの独自価値を明確にし、差別化を図る。

---

## 1. GAS バックエンドの優位性（MCP にない構造的強み）

MCP はクライアントサイドで Gmail API を叩くだけ。ccskill-gmail は GAS という「自分のサーバー」を持つ。

### バッチ操作 / 複合アクション

- 「検索 → ラベル付け → アーカイブ」を1回の API コールで完結
- MCP だと N 件 × 3 操作 = 3N 回の往復が必要
- 実装案: `batch` アクションで複数操作を配列で受け取る

### サーバーサイド集計

- 送信者別メール件数、ラベル別未読数などの集計を GAS 側で処理
- MCP だと全件取得してクライアント側で数える必要がある
- 実装案: `get_stats` / `get_summary` アクション

### GAS トリガー（時間駆動）

- 定期実行で未読メールダイジェストをスプレッドシートに書き出し
- MCP にはスケジュール実行の概念がない
- 実装案: トリガー設定用のアクション or GAS 側設定ガイド

---

## 2. ccskill シリーズ連携（最大の差別化ポイント）

個別ツールとしてではなく、シリーズとしてのシナジーが MCP には真似できない。

### Gmail × Spreadsheet

- 受信メールから請求書・領収書の金額を抽出 → シートに自動記録
- メール対応履歴をシートに蓄積（簡易 CRM）
- スプレッドシートの宛先リストからメールマージ下書き一括作成
- メール統計（日別受信数、送信者ランキング等）をシートに集約

### Gmail × Webapp

- メール統計ダッシュボードを Web ページとして公開
- 共有受信トレイのビューを Web で提供

### Gmail × nanobanana

- ニュースレター・お知らせメールの下書きに生成画像を添付

### 統合ユースケース例

> 「メールから請求情報を抽出してスプレッドシートに記録し、月次サマリーを Web ダッシュボードで公開する」
> — これが全部 ccskill シリーズで完結する

---

## 3. ccskill-gmail 単体の独自機能アイデア

### メールテンプレート機能

- GAS 側にテンプレート保存、変数差し込みで下書き生成
- `create_draft_from_template` アクション
- MCP は毎回本文を丸ごと渡す必要がある

### 添付ファイル付き下書き

- `GmailApp.createDraft()` に `InlineImage` / `Blob` を渡す
- 現在未実装、MCP にもない
- 画像やPDFを添付した下書きを作成可能に

### メール転送下書き

- `create_forward_draft` — 元メールの内容と添付を保持したまま転送下書き作成
- 返信下書き (`create_reply_draft`) と同様に MCP にはない

### スマート検索 / フィルタリング

- GAS 側で検索結果を後処理フィルタ（添付付きのみ、特定サイズ以上等）
- 本文から特定パターン（金額、URL、日付等）を抽出して返す

### メールエクスポート

- スレッド全体を EML / MBOX 形式でエクスポート
- 複数メールの一括 PDF 化（既存の PDF 機能を拡張）

---

## 4. 安全設計の深化

### 操作ログ

- GAS 側で「何をいつ実行したか」を記録
- ccskill-spreadsheet 連携でログをシートに書き出し

### 承認フロー

- 破壊的操作（ゴミ箱移動、大量ラベル操作等）に確認ステップを挟む

---

## 5. 現状の MCP 機能カバー状況

| MCP 機能 | ccskill-gmail | 備考 |
|----------|:---:|------|
| gmail_search_messages | o | search |
| gmail_read_message | o | get_message |
| gmail_read_thread | o | get_thread |
| gmail_list_drafts | - | → #042 で対応予定 |
| gmail_get_profile | - | → #043 で対応予定 |
| gmail_create_draft | o | create_draft |

042, 043 実装後は MCP の完全上位互換となる。

---

## 優先度の所感

1. **最優先**: #042 (list_drafts), #043 (get_profile) で MCP 完全上位互換化
2. **高**: ccskill シリーズ連携（特に Gmail × Spreadsheet）
3. **中**: メールテンプレート、添付付き下書き、転送下書き
4. **低**: バッチ操作、GAS トリガー、エクスポート機能
