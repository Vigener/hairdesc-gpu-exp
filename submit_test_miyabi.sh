#!/bin/bash
#PBS -q debug-g
#PBS -l select=2
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

echo "========================================"
echo "Running Minimal Test on Miyabi-G (2 nodes)"
echo "========================================"

# Miyabi-G は1ノードあたり1 GPU (GH200) のため、プロセスあたりのバインディング用 wrapper.sh は不要です。
N_CPU=1024
N_GPU=4096
NX=64
NODES=2

echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_cpu ${N_CPU} ${NODES}

echo "[2/4] N-body GPU (N=${N_GPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_cpu ${NX} ${NX} ${NX} ${NODES}

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_gpu ${NX} ${NX} ${NX} ${NODES}

echo "All tests finished successfully!"
