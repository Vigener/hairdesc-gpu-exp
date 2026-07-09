#!/bin/bash

# Miyabi-G用 極小サイズでの1〜4ノードスケーリング確認スクリプト
# 安全装置: walltime=00:03:00

N_GPU=4096
NX_GPU=64

for NODES in 1 2 4; do
  SCRIPT_NAME="job_miyabi_minimal_${NODES}nodes.sh"
  
  cat << IN_EOF > ${SCRIPT_NAME}
#!/bin/bash
#PBS -q regular-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

echo "========================================"
echo "Running Minimal Scaling Test on Miyabi-G (${NODES} nodes)"
echo "========================================"

echo "[1/2] N-body GPU (N=${N_GPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[2/2] Diffusion GPU (${NX_GPU}x${NX_GPU}x${NX_GPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_gpu ${NX_GPU} ${NX_GPU} ${NX_GPU} ${NODES}

echo "Minimal tests finished successfully!"
IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  echo "Generated and submitted ${SCRIPT_NAME}"
  
  qsub ${SCRIPT_NAME} 
done
