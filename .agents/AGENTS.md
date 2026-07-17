# Project-Scoped Rules for hairdesc-gpu-exp

このファイルは、AIエージェント（Antigravityなど）がこのプロジェクト内で作業する際のローカルルールを定義します。

## セキュリティに関する重要事項 (Security Rules)
このリポジトリ `hairdesc-gpu-exp` は **Public（公開設定）** となっています。
エージェントは以下のルールを厳守して作業を行ってください。

- PPXやMiyabiなどのHPCクラスタの**パスワード、SSH秘密鍵、APIキー等のクレデンシャル情報**をファイルに書き込んだり、Gitコミットに含めたりしないでください。
- `/home` パス上の非公開データセットへの絶対パスや、個人情報をスクリプトやMakefileにハードコードしないでください。
- もし一時的にテスト等でハードコードが必要になった場合は、コミット前に必ず `.gitignore` への追加やダミー値への置き換えを行ってください。

## 学習・実験ログの記録ルール (Logging Rule)
- 講義資料のどの部分を学ぶためにどんな実装をしたのか、実装の意図や、実験からわかったことなど、進めていく全ての内容（意思決定含む）について、必ずログとしてMarkdownファイル（例: `docs/learning_log.md`）に詳細にまとめていくこと。

## 同期・デプロイに関するルール (Sync & Deploy Rules)
- Miyabi などのリモート環境へファイルを同期（rsync）する際は、プログラムの実行に不要な `.md` ファイル（マークダウンドキュメント）や `docs/` フォルダを必ず除外してください。
- 以下のオプション例を参考にし、不要なファイル転送を防止してください。
  ```bash
  rsync -avz --exclude='.git' --exclude='bin' --exclude='out' --exclude='*.md' --exclude='docs/' ./ miyabi-g:/work/...
  ```

