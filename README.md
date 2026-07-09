# HAIRDESC GPU Acceleration Experiments (N-body & Diffusion3D)

このリポジトリは、HAIRDESCの演習資料に基づく「N体問題」と「3次元拡散方程式」のOpenACCを用いたGPU高速化、およびMPIを用いたマルチGPU並列化（GPU-Aware MPI）の性能評価の実験コードを管理しています。

> **⚠️ 注意事項 (Security Warning)**
> このリポジトリは **Public** リポジトリです。
> - PPXやMiyabiなどのクラスタアクセス情報、パスワード、機密データを絶対にコミットしないでください。
> - 個人的なAPIキーなどを混入させないよう十分注意してください。

## 現在の進捗状況
- **Phase 1**: `#pragma acc managed` (Unified Memory) によるマルチGPU化のベースライン実装とスケーリング評価（完了）
- **Phase 2**: `host_data use_device` と GPU-Aware MPI を用いた Unified Memory ボトルネックの排除と、OpenACC組み込みプロファイラによる通信・計算スケーリングの可視化（完了）
- **Phase 3**: 非同期MPI通信（`MPI_Isend` / `MPI_Irecv`）を用いた計算と通信のオーバーラップ実装（Next Step）

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

### 2. PPX環境（開発・デバッグ用環境）
コンパイル確認や単ノード・少ノードでのGPU動作確認を行う環境です。ローカルで編集したコードをPPXに同期し、Slurmジョブとして投入します。

```bash
# 1. エージェントが rsync でPPXへ変更を自動同期します
# 2. PPXにログインしてコンパイル＆ジョブ投入
ssh ppx
cd projects/hairdesc-gpu-exp
make -f Makefile.ppx clean
make -f Makefile.ppx

# 3. ジョブ生成スクリプトを実行し、Slurmへ投入
bash ./submit_test_ppx.sh
sbatch job_ppx_test_2nodes.sh

# 4. 実行結果の確認
cat out/*.out
```

### 3. スパコン・Miyabi環境（本番スケーリングテスト）
大規模なノード数での本番計測を行う環境です。Miyabi-G (GH200) を用いて、マルチGPUスケーリングの検証を行います。PBS Professionalを使用します。

```bash
# 1. エージェントが rsync でMiyabiへ変更を自動同期します
# 2. スパコン（Miyabi-G）にログイン
ssh miyabi-g
cd /work/xg26i048/x10752/projects/hairdesc-gpu-exp

# 3. スパコン環境でビルド
make -f Makefile.miyabi clean
make -f Makefile.miyabi

# 4. スケーリングテスト用ジョブの自動生成＆投入
bash ./submit_scaling_miyabi_gpu_only.sh
# 内部で qsub が順次実行されます

# 5. ジョブ状態の確認
qstat
```
