#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# コンパイル
make -f Makefile.miyabi build_cpu_fast build_cpu_soa

export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=$(cat ${PBS_NODEFILE} | wc -l)
N=64
STEPS=10

echo "=== Running AoS CPU version (N=${N}, STEPS=${STEPS}) ==="
mpiexec -n ${NODES} --map-by ppr:1:node ./bin/nbody_cpu_fast ${N} ${NODES} ${STEPS}
mv output_x.double output_x_aos.double
mv output_y.double output_y_aos.double
mv output_z.double output_z_aos.double

echo "=== Running SoA CPU version (N=${N}, STEPS=${STEPS}) ==="
mpiexec -n ${NODES} --map-by ppr:1:node ./bin/nbody_cpu_soa ${N} ${NODES} ${STEPS}
mv output_x.double output_x_soa.double
mv output_y.double output_y_soa.double
mv output_z.double output_z_soa.double

echo "=== Verifying numerical consistency ==="
if cmp output_x_aos.double output_x_soa.double && \
   cmp output_y_aos.double output_y_soa.double && \
   cmp output_z_aos.double output_z_soa.double; then
    echo "Verification SUCCESS: Numerical outputs are bitwise identical."
else
    echo "Verification FAILED: Numerical outputs differ."
    exit 1
fi
