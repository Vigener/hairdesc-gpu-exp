#!/bin/bash

# Miyabi-G用 GPU専用スケーリングテスト生成スクリプト
# トークン消費を最小限（最大3分）に抑えつつ、スケーリングが確認できる「中規模」サイズで実行します

# N-body (O(N^2))
# N=65536 の場合、1ノードで約100秒、8ノードで十数秒程度と推測され、スケーリングが綺麗に見えます。
N_GPU=65536

# Diffusion3D (O(N^3))
# 512^3 の場合、1ノードで数秒程度、ノード数に応じて短縮される様子がわかります。
NX_GPU=512

for NODES in 1 2 4 8; do
  SCRIPT_NAME="job_miyabi_scaling_gpu_${NODES}nodes.sh"
  
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
echo "Running GPU Scaling Test on Miyabi-G (${NODES} nodes)"
echo "========================================"

echo "[1/2] N-body GPU (N=${N_GPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[2/2] Diffusion GPU (${NX_GPU}x${NX_GPU}x${NX_GPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_gpu ${NX_GPU} ${NX_GPU} ${NX_GPU} ${NODES}

echo "GPU tests finished successfully!"
IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  echo "Generated and submitted ${SCRIPT_NAME}"
  
  # Miyabiに順次ジョブを投入
  qsub ${SCRIPT_NAME} 
done
