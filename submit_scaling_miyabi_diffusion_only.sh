#!/bin/bash

# Miyabi-G用 Diffusion3D(GPU) 専用スケーリングテスト生成スクリプト
# トークン消費を最小限（最大3分）に抑えつつ、通信オーバーヘッドを上回れるか巨大サイズで検証します

# Diffusion3D (O(N^3))
# 1024^3 の場合、データ量は約16GB。1ノードで数秒程度かかると推測されます。
NX_GPU=1024

for NODES in 1 2 4 8; do
  SCRIPT_NAME="job_miyabi_scaling_diff_${NODES}nodes.sh"
  
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
echo "Running Diffusion GPU Scaling Test on Miyabi-G (${NODES} nodes)"
echo "========================================"

echo "Diffusion GPU (${NX_GPU}x${NX_GPU}x${NX_GPU})"
NVCOMPILER_ACC_TIME=1 mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_gpu ${NX_GPU} ${NX_GPU} ${NX_GPU} ${NODES}

echo "Diffusion test finished successfully!"
IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  echo "Generated and submitted ${SCRIPT_NAME}"
  
  # Miyabiに順次ジョブを投入
  qsub ${SCRIPT_NAME} 
done
