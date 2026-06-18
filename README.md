# HAIRDESC GPU Acceleration Experiments (nbody)

このリポジトリは、HAIRDESCの演習資料に基づくN体問題のOpenACCなどを用いたGPU高速化と性能評価の実験コードを管理しています。

> **⚠️ 注意事項 (Security Warning)**
> このリポジトリは **Public** リポジトリです。
> - PPXやMiyabiなどのクラスタアクセス情報、パスワード、機密データを絶対にコミットしないでください。
> - 個人的なAPIキーなどを混入させないよう十分注意してください。

## 開発と実行のワークフロー

このプロジェクトでは、ローカル（Mac等）でのソースコード編集と、HPCクラスタ（PPXやMiyabi）での実行環境を同期させながら開発を進めます。

### 1. 日々の細かい開発（rsyncによる高速同期）

ソースコードをローカルで編集し、クラスタ側でコンパイル・実行テストを回す際のワークフローです。毎回 Git を経由するのではなく、Makefile やエイリアスに設定したコマンドを利用して直接同期します。

```bash
# 1. ローカルでコードを編集
# (Zedなどで src/nbody_openacc.cpp 等を編集)

# 2. PPX/Miyabiへ変更を同期
make push-ppx PJ=projects/hairdesc-gpu-exp

# 3. PPXにログインしてコンパイル＆ジョブ投入
# (PPXターミナル内で)
cd projects/hairdesc-gpu-exp
make run_acc

# 4. 実行結果(out/など)をローカルに同期して確認
make pull-ppx PJ=projects/hairdesc-gpu-exp
```
*(※ `push-ppx` / `pull-ppx` コマンドはご自身の環境に合わせて適宜読み替えてください)*

### 2. まとまった単位の同期（Git）

1日の初めや終わり、あるいは主要な機能が実装できたタイミングでの同期手順です。こちらは変更履歴を確実に残すために Git を使用します。

```bash
# ローカルでコミット＆プッシュ
git add .
git commit -m "OpenACC実装の追加"
git push

# クラスタ（PPX/Miyabi）側で最新版を取得
# (PPXターミナル内で)
git pull
```
