# ccskill-gmail

**Gmail での作業を、もっともっと楽にする。**

ccskill-gmail は、Claude Code 標準の Gmail コネクタ (MCP) を補完するスキルです。標準コネクタでは不可能な複数 Gmail アカウントの使い分け、添付ファイルのダウンロード・メール本文の PDF 化・プロンプトインジェクション対策等に対応しています。

単一アカウントでの日常的な検索・閲覧・返信下書き作成のみであれば、標準 Gmail コネクタの方が使いやすい可能性があります。ただ本スキルにも同じ機能が一式備わっていますので、標準コネクタの代わりとして使用することもできます。

## 機能比較

| 機能 / タスク | 標準コネクタ | Workspace MCP (プレビュー) | ccskill-gmail |
|---|:---:|:---:|:---:|
| メールの検索と内容の確認 | ○ | ○ | ○ |
| メールの下書き作成 | ○ | ○ | ○ |
| ラベルの付与・削除 | × | ○ | ○ |
| マルチアカウント対応 | × | × | ○ |
| ゴミ箱への移動 | × | × | ○ |
| アーカイブ | × | × | ○ |
| 未読・既読のトグル | × | × | ○ |
| スター付与 | × | × | ○ |
| 添付ファイルのダウンロード | × | × | ○ |
| メール本文の PDF 化 | × | × | ○ |
| プロンプトインジェクション対策（HTML メール中の隠しプロンプトの無効化） | × | × | ○ |
| メール操作の監査ログ | × | × | ○ |
| Gmail 連携スクリプトの開発 | × | × | ○ |

出典: [Claude 公式ドキュメント「Google Workspace コネクタを使用する」](https://support.claude.com/en/articles/10166901-use-google-workspace-connectors) / [Google「Workspace MCP サーバーを構成する」](https://developers.google.com/workspace/guides/configure-mcp-servers?hl=ja)

## 特徴的な機能

### 複数アカウント対応

複数の Gmail アカウントに対応しています。一度登録するだけで、どのプロジェクトからでもアカウントを切り替えながらメール操作が可能になります。

### 添付ファイルのダウンロード

添付ファイルをダウンロード可能です。メール本文に応じたファイル名で保存したり、添付ファイルの内容を踏まえた作業を指示することができます。

### メール本文のPDFファイル化

メール本文をPDFファイルとして保存できます。HTMLメール・テキストメールの両方に対応しています。

### セキュリティ

ccskill-gmail は安全に使用できることを前提に開発されてます。

- **送信機能はありません。** Claude Code が下書きを作成し、送信はユーザが Gmail から手動で行う設計です（標準コネクタも同じ思想）
- **ゴミ箱移動はデフォルト無効。** 必要な場合は `config.js` でオプトインしてください
- **プロンプトインジェクション対策。** HTML メールに埋め込まれた隠し指示（CSS 非表示・ゼロ幅文字・白文字等）は、GAS 層で無効化してから AI に渡します
- **Googleアカウント認証前提。** Google アカウントで認証することを前提とした作りになっています。

## 使用例
### 複数アカウントを横断して扱う

> 「work と private の両方のアカウントで、今週まだ返信していないメールを探して、アカウント別に送信者と件名を一覧にして」

### 添付ファイルの領収書を整理

> 「○○社からの領収書メールを直近半年分探して、添付PDFを `20260401_取引先名_税込金額_receipt.pdf` の形式で保存して」

### 過去のメールやり取りの整理

> 「○○システムの障害対応メールを過去1年分調べて、発生日・原因・対処法の一覧を作って」

### 不要メールのアーカイブ

> 「メーリングリストや通知系メールを抽出して、送信元・頻度・最終受信日の一覧を作って。3ヶ月以上未読が放置されているメールはアーカイブして」

### 独自スクリプトの開発

> 「今月届いた請求書メールから PDF 添付を一括ダウンロードするスクリプトを書いて」

## インストール

### 0. 前提条件

- Google アカウント (個人 / Google Worksspace)
- Node.js / npm
- jq
- Google Apps Script API の有効化 (初めて GAS を使う場合には [Google Apps Script API の設定](https://script.google.com/home/usersettings) をオンにする必要があります)



### 1. スキルの入手

**git clone の場合:**

```bash
cd ~/projects
git clone https://github.com/feedtailor/ccskill-gmail.git
```

**zip 配布の場合:**

```bash
cd ~/projects
unzip ccskill-gmail-XXXXXX.zip
```

### 2. セットアップ

```bash
cd ~/projects/ccskill-gmail
./ccskill-gmail setup
```
(途中ブラウザでGoogle認証が求められるので「許可」してください)

### 3. 2つ目以降のアカウント登録（任意）

2つ目以降のアカウントを追加する場合、以下を実行してください。

```bash
ccskill-gmail account add
```

ブラウザでの Google 認証後、追加したアカウントのラベル(識別子)を求められますので、`work` や `personal` など任意の文字列をして下さい。(半角英数字、ハイフン、アンダースコアが利用可)

## 旧 ccskill-gmail をご利用の方へ

2026年5月以前に ccskill-gmail を使い始めた方は、以下コマンドを実行してください。再ログインは不要です。

```bash
cd ~/projects/ccskill-gmail
git pull
ccskill-gmail migrate
```

## 更新

ccskill-gmail は機能追加や不具合修正で更新されることがあります。

### git clone の場合

最新コードを取得しアカウント共有 GAS を再デプロイします。

```bash
cd ~/projects/ccskill-gmail
git pull
ccskill-gmail account update
```

### zip 配布の場合

新しい zip を上書き展開し、アカウント共有 GAS を再デプロイします（`git pull` が `unzip -o` に変わるだけです）。

```bash
cd ~/projects
unzip -o ccskill-gmail-XXXXXX.zip     # ディレクトリに上書き展開
ccskill-gmail account update
```

## アンインストール

このマシンから ccskill-gmail を一括で取り除きます（ユーザースキル・全アカウント登録・CLI を一度に削除）。

```bash
ccskill-gmail uninstall --all          # 削除内容を確認後、まとめて撤去（--dry-run で確認のみ）
```

GAS プロジェクト（Google 側）と clasp トークンは自動削除されません。完全に消すには [script.google.com](https://script.google.com) から GAS を手動削除してください。

## 参考資料

| 資料 | 内容 |
|---|---|
| [コマンド一覧](docs/commands.ja.md) | `ccskill-gmail` の全コマンドとオプション |
| [技術情報](docs/technical-details.ja.md) | アーキテクチャ、claspやGmail の権限スコープ、スキル定義ドキュメント |
| [トラブルシューティング](docs/troubleshooting.ja.md) | よくある問題と対処（認証エラー・更新が反映されない 等） |

## サポート

サポートは一切行っていません。ご質問等を頂いてもご回答は致しません。無償で公開しているものですので何卒ご了承下さい。法人や業務用途等でサポートが必要な場合、[こちら](https://www.feedtailor.jp/product_advisory-claudecode/)をご契約下さい。

## ライセンス

MIT License
