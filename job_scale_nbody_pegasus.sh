#!/bin/bash
#PBS -q gpu
#PBS -A QHPC
#PBS -b 32
#PBS -l elapstim_req=01:00:00
#PBS -T openmpi

cd ${PBS_O_WORKDIR}
module load nvhpc-nompi openmpi

N_CPU=20000
N_GPU=100000

echo "Scaling N-body CPU (N=${N_CPU})"
for NODES in 1 2 4 8 16 32; do
    echo "Running CPU on ${NODES} nodes"
    mpirun ${NQSV_MPIOPTS} -np ${NODES} -npernode 1 ./bin/nbody_cpu ${N_CPU} ${NODES}
done

echo "Scaling N-body GPU (N=${N_GPU})"
for NODES in 1 2 4 8 16 32; do
    echo "Running GPU on ${NODES} nodes"
    TOTAL_PROCS=$((NODES * 4))
    mpirun ${NQSV_MPIOPTS} -np ${TOTAL_PROCS} -npernode 4 ./wrapper.sh ./bin/nbody_gpu ${N_GPU} ${NODES}
done
