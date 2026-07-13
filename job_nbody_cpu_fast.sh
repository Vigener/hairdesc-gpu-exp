#!/bin/bash
#PBS -q short-c
#PBS -l select=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# Miyabi-C (Intel Xeon MAX) 用にコンパイル
make -f Makefile.miyabi-c build_cpu_fast

# CPU版の実行: 1ノードあたり1MPIプロセスとし、マルチスレッドをフル活用する
export OMP_NUM_THREADS=112
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=$(cat ${PBS_NODEFILE} | wc -l)
N=${N:-10000}
STEPS=${STEPS:-100}

echo "Running CPU version on ${NODES} nodes (N=${N}, STEPS=${STEPS})..."
mpiexec.hydra -n ${NODES} ./bin/nbody_cpu_fast ${N} ${NODES} ${STEPS}
