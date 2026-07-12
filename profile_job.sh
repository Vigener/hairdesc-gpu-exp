#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail

cd ${PBS_O_WORKDIR}

# ビルド
make -f Makefile.miyabi clean
make -f Makefile.miyabi build_diff_gpu

# 実行ディレクトリ作成
mkdir -p out

# 1. Nsight Systems によるプロファイリング (NX=256など小さめのサイズで実行)
echo "Running Nsight Systems..."
mpirun -n 1 --map-by ppr:1:node --bind-to none nsys profile -f true -o out/diffusion_nsys bin/diffusion_gpu 1 256

# 2. Nsight Compute によるプロファイリング
echo "Running Nsight Compute..."
mpirun -n 1 --map-by ppr:1:node --bind-to none ncu --set full -f -o out/diffusion_ncu bin/diffusion_gpu 1 256

echo "Profiling completed."
