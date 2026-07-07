#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:10:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# CPU版の実行: 1ノードあたり1MPIプロセスとし、マルチスレッドをフル活用する
export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=$(cat ${PBS_NODEFILE} | wc -l)
N=256

echo "Running 3D Diffusion CPU version on ${NODES} nodes..."
mpiexec -n ${NODES} --map-by ppr:1:node ./bin/diffusion_cpu ${NODES} ${N}
