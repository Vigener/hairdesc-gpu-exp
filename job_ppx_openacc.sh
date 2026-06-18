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

# 実行
./bin/nbody_openacc

echo "Finished"
date
