#!/bin/bash
#PBS -q debug-g
#PBS -l select=2
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# ビルド実行
make -f Makefile.miyabi build_gpu_fast
make -f Makefile.miyabi build_gpu_soa

N=65536
STEPS=100

echo "=== N-body 本番規模性能比較 (N=${N}, STEPS=${STEPS}) ==="
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"

# --- 1ノード (1 GPU) 実行 ---
echo "--- 1 Node Execution ---"
echo "GPU_AOS_1NODE:"
mpiexec -n 1 --map-by ppr:1:node --bind-to none ./bin/nbody_gpu_fast ${N} 1 ${STEPS}

echo "GPU_SOA_1NODE:"
mpiexec -n 1 --map-by ppr:1:node --bind-to none ./bin/nbody_gpu_soa ${N} 1 ${STEPS}

# --- 2ノード (2 GPU) 実行 ---
echo "--- 2 Nodes Execution ---"
echo "GPU_AOS_2NODES:"
mpiexec -n 2 --map-by ppr:1:node --bind-to none ./bin/nbody_gpu_fast ${N} 2 ${STEPS}

echo "GPU_SOA_2NODES:"
mpiexec -n 2 --map-by ppr:1:node --bind-to none ./bin/nbody_gpu_soa ${N} 2 ${STEPS}
