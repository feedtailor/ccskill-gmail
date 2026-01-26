# Gmail Skill

エージェントAI（Claude Code等）が Gmail を検索・閲覧・下書き作成できるようにするスキルです。

## 概要

本スキルを使うと、Claude Code が自然言語の指示だけで Gmail を操作できるようになります。メールの確認、返信下書きの作成、メール整理などに活用できます。

**動作の流れ:**

1. ユーザーが自然言語で指示（例：「未読メールを確認して返信を書いて」）
2. Claude Code がスキル（SKILL.md）を参照し、適切な API を選択
3. curl コマンドで GAS Web App にリクエスト送信
4. GAS が Gmail を操作し、結果を JSON で返却
5. Claude Code が結果をユーザーに報告

## 特徴

- **簡単インストール**: スクリプト一発で任意のプロジェクトに導入可能
- **自然言語操作**: ユーザーは API を意識せず、日本語で指示するだけ
- **安全設計**: 送信機能はなし（下書き作成のみ）、誤送信を防止

## 安全設計

**送信機能は意図的に含めていません。**

- 誤送信防止: AI が直接送信すると取り消し不可
- 確認フロー: 人間が Gmail UI で内容確認 → 送信
- 責任の明確化: 送信は人間の意思決定

## Prerequisites

- Google アカウント
- Node.js（clasp のため）
- Bash環境（Linux, macOS, WSL）

## グローバルインストール（初回のみ）

### 1. リポジトリのクローン

```bash
cd ~/projects  # または任意のディレクトリ
git clone https://github.com/feedtailor/ccskill-gmail.git
```

### 2. 環境変数の設定

`~/.zshrc` または `~/.bashrc` に以下を追加:

```bash
export CCSKILL_GMAIL_DIR=~/projects/ccskill-gmail
```

再読み込み:

```bash
source ~/.zshrc  # または source ~/.bashrc
```

### 3. clasp のインストールとログイン（初回のみ）

```bash
npm install -g @google/clasp
clasp login
```

これでグローバルインストールは完了です。

## プロジェクトへのインストール

### 1. インストールスクリプトの実行

```bash
cd /path/to/your-project
$CCSKILL_GMAIL_DIR/install.sh
```

インストーラーが以下を自動で行います:

1. スキル定義を `.claude/skills/ccskill-gmail/` にコピー
2. GASコードを `.ccskill-gmail/` にコピー
3. GAS プロジェクトの作成とコードプッシュ
4. GAS エディタを開く（デプロイは手動）
5. エンドポイント URL の検証
6. `.env` ファイルへの保存

### 2. 手動デプロイ

GAS エディタで以下の設定でデプロイ:

- **Execute as**: Me
- **Who has access**: Anyone（必須）

### 3. OAuth スコープの承認

初回デプロイ時に Gmail へのアクセス権限の承認が必要です。

### 4. .gitignore への追加（推奨）

プロジェクトの `.gitignore` に以下を追加:

```
# Gmail Skill
.ccskill-gmail/
.env
```

## 使い方

インストール完了後、Claude Code に自然言語で指示するだけです。

### 基本的な使用例

```
「未読メールを見せて」

「重要なメールを確認して」

「このメールに返信下書きを作成して：承知いたしました」

「メールを既読にしてアーカイブして」

「対応済ラベルを付けて」
```

Claude が適切な API を選択し、Gmail を操作します。

### API 一覧

#### 読み取り系（GET）

| API | 説明 |
|-----|------|
| search | メール検索 |
| get_thread | スレッド取得 |
| get_message | メッセージ詳細 |
| list_labels | ラベル一覧 |
| get_unread_count | 未読数取得 |

#### 書き込み系（POST）

| API | 説明 |
|-----|------|
| create_draft | 新規メール下書き作成 |
| create_reply_draft | 返信下書き作成 |
| update_draft | 下書き更新 |
| delete_draft | 下書き削除 |
| mark_read / mark_unread | 既読・未読操作 |
| add_label / remove_label | ラベル操作 |
| archive | アーカイブ |
| move_to_trash | ゴミ箱に移動 |

### より詳しい例

`.claude/skills/ccskill-gmail/examples.md` に、メール確認、返信作成、メール整理などのワークフロー例があります。

## スキルの更新

グローバルリポジトリが更新された場合:

```bash
# 1. グローバルリポジトリを更新
cd ~/projects/ccskill-gmail
git pull

# 2. プロジェクトのスキルを更新
cd /path/to/your-project
$CCSKILL_GMAIL_DIR/update.sh
```

`update.sh` は以下を自動で行います:

- スキル定義（SKILL.md等）を最新版にコピー
- GASコードを最新版にコピー
- clasp push で GAS を更新

**Note**: 新しい API が追加された場合は、GAS エディタで新しいデプロイメントを作成する必要があります。

## アンインストール

### プロジェクトからの削除

```bash
cd /path/to/your-project
$CCSKILL_GMAIL_DIR/uninstall.sh
```

アンインストーラーが以下を自動で行います:

1. スキル定義 `.claude/skills/ccskill-gmail/` の削除
2. GASコード `.ccskill-gmail/` の削除
3. `.env` から `GMAIL_ENDPOINT` エントリの削除
4. GASプロジェクト削除方法の表示

### GAS Web App の削除

アンインストーラーが表示する手順に従って、Google Apps Script ダッシュボードからプロジェクトを削除してください。

これで Gmail への外部アクセスは完全に遮断されます。

## 技術詳細

### ディレクトリ構造

**グローバルリポジトリ:**
```
ccskill-gmail/
├── .claude/skills/ccskill-gmail/  # スキル定義テンプレート
├── gas-template/                   # GASコードテンプレート
├── install.sh                      # インストールスクリプト
├── update.sh                       # 更新スクリプト
├── uninstall.sh                    # アンインストールスクリプト
└── README.md
```

**プロジェクトにインストール後:**
```
my-project/
├── .claude/skills/ccskill-gmail/  # スキル定義（コピー）
├── .ccskill-gmail/                # GASコード（独立）
│   ├── .clasp.json
│   ├── .ccskill-metadata.json     # メタデータ
│   └── src/
└── .env                           # エンドポイント
```

### API 仕様

詳細は以下のドキュメントを参照:

- [SKILL.md](.claude/skills/ccskill-gmail/SKILL.md) - スキル概要と curl 実行ルール
- [reference/](.claude/skills/ccskill-gmail/reference/) - 全 API の詳細仕様
- [examples.md](.claude/skills/ccskill-gmail/examples.md) - ワークフロー例
- [troubleshooting.md](.claude/skills/ccskill-gmail/troubleshooting.md) - トラブルシューティング

## 制限事項

- **送信機能なし**: 下書き作成のみ（送信は Gmail UI で手動）
- **GAS 実行時間制限**: 6分/実行
- **日次実行時間制限**: 90分/日
- **添付ファイル**: 現在は添付ファイルの追加・ダウンロードは未対応

## ライセンス

MIT License
