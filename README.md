# HAIRDESC GPU Acceleration Experiments (nbody)

このリポジトリは、HAIRDESCの演習資料に基づくN体問題のOpenACCなどを用いたGPU高速化と性能評価の実験コードを管理しています。

> **⚠️ 注意事項 (Security Warning)**
> このリポジトリは **Public** リポジトリです。
> - PPXやMiyabiなどのクラスタアクセス情報、パスワード、機密データを絶対にコミットしないでください。
> - 個人的なAPIキーなどを混入させないよう十分注意してください。

## 開発と実行のワークフロー

このプロジェクトでは、**ローカルコンテナ（ミニマムテスト）**、**PPX（開発・テスト用HPC）**、**スパコン（本番環境）**の3つの環境を使い分けて開発を進めます。

### 1. ローカル環境（Mac上のコンテナ）
Macのローカル環境では、OrbStack等で構築したDockerコンテナを用いて、コードのコンパイル確認や小規模な動作確認（dry-run）を行います。Slurm環境はないため、直接バイナリを実行します。

```bash
# 1. コンテナへの入り方
docker exec -it mpi-dev-env bash

# 2. コンテナ内でのコンパイルとローカル実行（テストデータを利用した小規模実行）
make run_local
```

### 2. PPX環境（共有してからテスト実行する流れ）
GPU（OpenACC）や複数ノードでの本格的なテストを行う環境です。ローカルで編集したコードをPPXに同期し、Slurmジョブとして投入します。

```bash
# 1. ローカルでコードを編集し、PPXへ変更を同期 (rsync等のエイリアスやGitを利用)
# (例) make push-ppx PJ=projects/hairdesc-gpu-exp

# 2. PPXにログインしてコンパイル＆ジョブ投入
cd projects/hairdesc-gpu-exp
make run      # MPI+OpenMP ハイブリッド版のビルド＆実行
# または
make run_acc  # OpenACC版のビルド＆実行

# 3. 実行結果(out/など)をローカルに同期して確認
# (例) make pull-ppx PJ=projects/hairdesc-gpu-exp
```

### 3. スパコン・Miyabi環境（本番の実行をする流れ）
大規模なノード数での本番計測を行う環境です。基本的な流れはPPXと同様ですが、変更履歴を確実に管理するため、本番実行時はGitを経由した同期を推奨します。

```bash
# 1. ローカルで動作確認を終えたコードをコミット＆プッシュ
git add .
git commit -m "feat: 完成したOpenACC実装を追加"
git push

# 2. スパコン（Miyabi等）にログインし、最新版を取得
cd projects/hairdesc-gpu-exp
git pull

# 3. スパコン環境でビルド＆本番ジョブ投入
make build
sbatch nbody_hybrid.sh  # (※Miyabi環境等に合わせたジョブスクリプトを使用)
```
