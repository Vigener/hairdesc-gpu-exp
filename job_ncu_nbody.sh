#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# コンパイル確認
make -f Makefile.miyabi build_gpu_fast

echo "=== Nsight Compute Profiling: N-body (1 Node) ==="
# オーバーヘッド削減のため、N=16384, STEPS=1 で極小実行
ncu --set full -f -o ncu_nbody_analysis \
  ./bin/nbody_gpu_fast 16384 1 1

echo "Profiling completed. Please sync 'ncu_nbody_analysis.ncu-rep' to your Mac."
