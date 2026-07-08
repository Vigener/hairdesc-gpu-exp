#!/bin/bash

# 実行パラメータ
N_CPU=10000
N_GPU=100000
NX=512

for NODES in 1 2 4 8 16 32; do
  SCRIPT_NAME="job_pegasus_${NODES}nodes.sh"
  cat << IN_EOF > ${SCRIPT_NAME}
#!/bin/bash
#PBS -q gpu
#PBS -A QHPC
#PBS -b ${NODES}
#PBS -l elapstim_req=00:15:00
#PBS -T openmpi

cd \${PBS_O_WORKDIR}
module load nvhpc-nompi openmpi

echo "========================================"
echo "Running on \${NODES} nodes"
echo "========================================"

echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun \${NQSV_MPIOPTS} -np ${NODES} -npernode 1 ./bin/nbody_cpu ${N_CPU} ${NODES}

echo "[2/4] N-body GPU (N=${N_GPU})"
TOTAL_PROCS=\$(( ${NODES} * 4 ))
mpirun \${NQSV_MPIOPTS} -np \${TOTAL_PROCS} -npernode 4 ./wrapper.sh ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun \${NQSV_MPIOPTS} -np ${NODES} -npernode 1 ./bin/diffusion_cpu ${NX} ${NX} ${NX} ${NODES}

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
TOTAL_PROCS=\$(( ${NODES} * 4 ))
mpirun \${NQSV_MPIOPTS} -np \${TOTAL_PROCS} -npernode 4 ./wrapper.sh ./bin/diffusion_gpu ${NX} ${NX} ${NX} ${NODES}

IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  # qsub コマンドはユーザーに実行してもらうため、ここではスクリプト生成のみ
  echo "Generated ${SCRIPT_NAME}"
done
