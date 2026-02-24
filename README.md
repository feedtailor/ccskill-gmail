# Gmail Skill

エージェントAI（Claude Code等）が Gmail を検索・閲覧・下書き作成できるようにするスキルです。

## 概要

本スキルを使うと、Claude Code が自然言語の指示だけで Gmail を操作できるようになります。メールの確認、返信下書きの作成、メール整理などに活用できます。

**動作の流れ:**

1. ユーザーが自然言語で指示（例：「未読メールを確認して返信を書いて」）
2. Claude Code がスキル（SKILL.md）を参照し、適切な API を選択
3. `ccskill-get` / `ccskill-post` で GAS Web App にリクエスト送信
4. GAS が Gmail を操作し、結果を JSON で返却
5. Claude Code が結果をユーザーに報告

## 特徴

- **簡単インストール**: `ccskill-gmail install` で任意のプロジェクトに導入可能
- **自然言語操作**: ユーザーは API を意識せず、日本語で指示するだけ
- **安全設計**: 送信機能はなし（下書き作成のみ）、誤送信を防止

## セキュリティ

- GAS Web App は **「自分のみ」(MYSELF)** でデプロイ
- OAuth Bearer トークンによる認証（clasp login で取得）
- エンドポイント URL は `script.google.com` のみ許可（ホワイトリスト）
- トークンの自動リフレッシュ対応

## Prerequisites

- Google アカウント
- Node.js（clasp のため）
- jq
- Bash環境（Linux, macOS, WSL）

## グローバルインストール（初回のみ）

### 1. リポジトリのクローン

```bash
cd ~/projects  # または任意のディレクトリ
git clone https://github.com/feedtailor/ccskill-gmail.git
```

### 2. PATH の設定

`~/.zshrc` または `~/.bashrc` に以下を追加:

```bash
export PATH="$HOME/projects/ccskill-gmail:$PATH"
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

## インストール

```bash
ccskill-gmail install [プロジェクト名] [ターゲットディレクトリ]
```

### 例

```bash
# カレントディレクトリにインストール
ccskill-gmail install my-project

# 特定ディレクトリにインストール
ccskill-gmail install my-project /path/to/project
```

インストーラーが以下を自動で行います:

1. スキル定義を `.claude/skills/ccskill-gmail/` にコピー
2. GAS プロジェクトの作成と自動デプロイ
3. OAuth 認可フロー（ブラウザで1回のみ）
4. エンドポイント URL の検証と `.env` への保存
5. `auth.sh` / `api.sh` をプロジェクトにコピー
6. Claude Code パーミッションの自動設定（opt-in）
7. レジストリへの登録

## コマンド

| コマンド | 説明 |
|----------|------|
| `ccskill-gmail install` | プロジェクトにインストール |
| `ccskill-gmail uninstall` | プロジェクトからアンインストール |
| `ccskill-gmail update` | インストール済みスキルを更新 |
| `ccskill-gmail update-all` | 全インストール先を一括更新 |
| `ccskill-gmail apply-config` | config.js の変更を GAS に反映 |
| `ccskill-gmail register` | 既存インストールをレジストリに登録 |
| `ccskill-gmail status` | 全インストール先の状態を表示 |
| `ccskill-gmail help` | ヘルプを表示 |
| `ccskill-gmail version` | バージョンを表示 |

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

```bash
# 1. グローバルリポジトリを更新
cd ~/projects/ccskill-gmail
git pull

# 2. プロジェクトのスキルを更新
cd /path/to/your-project
ccskill-gmail update

# 3. 全プロジェクトを一括更新
ccskill-gmail update-all
```

## アンインストール

```bash
cd /path/to/your-project
ccskill-gmail uninstall
```

## プロジェクト構成

```
ccskill-gmail/
├── ccskill-gmail              # メインコマンド（ディスパッチャ）
├── commands/                   # サブコマンド
│   ├── install.sh
│   ├── uninstall.sh
│   ├── update.sh
│   ├── update-all.sh
│   ├── apply-config.sh
│   ├── register.sh
│   └── status.sh
├── lib/                        # 共通ライブラリ
│   ├── auth.sh                # OAuth 認証
│   ├── api.sh                 # API ラッパー
│   ├── push-gas.sh            # GAS push/deploy
│   ├── registry.sh            # レジストリ管理
│   └── permissions.sh         # パーミッション設定
├── gas-template/               # GAS ソースコード
│   ├── appsscript.json
│   ├── config.js.template
│   ├── main.js
│   ├── handlers/
│   └── utils/
└── .claude/skills/ccskill-gmail/  # スキル定義
```

## 関連ドキュメント

- [SKILL.md](.claude/skills/ccskill-gmail/SKILL.md) - スキル概要と API テンプレート
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
