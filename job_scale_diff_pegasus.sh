#!/bin/bash
#PBS -q gpu
#PBS -A QHPC
#PBS -b 32
#PBS -l elapstim_req=00:30:00
#PBS -T openmpi

cd ${PBS_O_WORKDIR}
module load nvhpc-nompi openmpi

NX=512
NY=512
NZ=512

echo "Scaling Diffusion CPU (${NX}x${NY}x${NZ})"
for NODES in 1 2 4 8 16 32; do
    echo "Running CPU on ${NODES} nodes"
    mpirun ${NQSV_MPIOPTS} -np ${NODES} -npernode 1 ./bin/diffusion_cpu ${NX} ${NY} ${NZ} ${NODES}
done

echo "Scaling Diffusion GPU (${NX}x${NY}x${NZ})"
for NODES in 1 2 4 8 16 32; do
    echo "Running GPU on ${NODES} nodes"
    TOTAL_PROCS=$((NODES * 4))
    mpirun ${NQSV_MPIOPTS} -np ${TOTAL_PROCS} -npernode 4 ./wrapper.sh ./bin/diffusion_gpu ${NX} ${NY} ${NZ} ${NODES}
done
