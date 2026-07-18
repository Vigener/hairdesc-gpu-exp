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
# MPI環境の初期化エラーを避けるため、mpiexec -n 1 経由で ncu を実行します
mpiexec -n 1 ncu --set full -f -o ncu_nbody_analysis ./bin/nbody_gpu_fast 16384 1 1

echo "Profiling completed. Please sync 'ncu_nbody_analysis.ncu-rep' to your Mac."
