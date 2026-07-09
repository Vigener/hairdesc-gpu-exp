#!/bin/bash

# Miyabi-G用 スケーリングテスト生成スクリプト
# 1, 2, 4, 8ノードで極小問題サイズ（デッドロックやエラーなく最後まで回るか）をテストします。

N_CPU=1024
N_GPU=4096
NX=64

for NODES in 1 2 4 8; do
  SCRIPT_NAME="job_miyabi_scaling_${NODES}nodes.sh"
  
  cat << IN_EOF > ${SCRIPT_NAME}
#!/bin/bash
#PBS -q regular-g
#PBS -l select=${NODES}
#PBS -l walltime=00:15:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

echo "========================================"
echo "Running Scaling Test on Miyabi-G (${NODES} nodes)"
echo "========================================"

echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_cpu ${N_CPU} ${NODES}

echo "[2/4] N-body GPU (N=${N_GPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_cpu ${NX} ${NX} ${NX} ${NODES}

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_gpu ${NX} ${NX} ${NX} ${NODES}

IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  echo "Generated and submitted ${SCRIPT_NAME}"
  
  # Miyabiに順次ジョブを投入
  qsub ${SCRIPT_NAME} 
done
