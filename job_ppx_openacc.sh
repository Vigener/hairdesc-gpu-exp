#!/bin/bash
#SBATCH -J nbody_acc
#SBATCH -p ppx2
#SBATCH -N 1
#SBATCH --gpus=1
#SBATCH -o out/%j.out
#SBATCH -e out/%j.err

set -euo pipefail

# ログ出力先ディレクトリの確保
mkdir -p out bin

# 環境のロード (PPXでのGPUコンパイラ/実行環境をロード)
module load nvhpc || true

echo "Starting OpenACC N-body simulation on PPX"
date

# CSVファイルの準備
CSV_FILE="out/results_nbody_acc_$(date +%Y%m%d_%H%M%S).csv"
echo "Nodes,MPI_Processes,OpenMP_Threads,NumParticles,Time_sec" | tee "$CSV_FILE"

# 実行
res=$(./bin/nbody_openacc)

# 結果の出力とCSVへの抽出
echo "$res"
echo "$res" | grep -E '^[0-9]+,[0-9]+,[0-9]+,[0-9]+,[0-9.]+$' >> "$CSV_FILE"

echo "Finished"
date

# 最新結果のコピー
cp "$CSV_FILE" "out/results_nbody_acc_latest.csv"
echo "Experiment complete. Results saved to ${CSV_FILE} and copied to out/results_nbody_acc_latest.csv"
