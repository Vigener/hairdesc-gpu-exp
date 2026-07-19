#!/bin/bash
#PBS -q debug-g
#PBS -l select=2
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# コンパイル
make -f Makefile.miyabi build_cpu_soa

export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

N=65536
STEPS=100

echo "=== Running CPU SoA 2 Nodes ==="
mpiexec -n 2 --map-by ppr:1:node ./bin/nbody_cpu_soa ${N} 2 ${STEPS}
