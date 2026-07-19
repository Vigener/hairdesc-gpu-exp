#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# SoA版をコンパイル (Makefile.miyabiの変更でfastmathが自動的に適用される)
make -f Makefile.miyabi build_gpu_soa

echo "=== Nsight Compute Profiling: N-body SoA Fast Math (1 Node) =="
# debug-gで安全に3分以内で終わらせるため、極小パラメータ 16384 1 1 でプロファイル
mpiexec -n 1 ncu --set full -f -o ncu_nbody_soa_fastmath_analysis ./bin/nbody_gpu_soa 16384 1 1

echo "Profiling completed. Please sync 'ncu_nbody_soa_fastmath_analysis.ncu-rep' to your Mac."
