#!/bin/bash

# PPX用スケーリングテスト生成スクリプト
# 1~4ノードで極小テストを行います

N_CPU=1024
N_GPU=4096
NX=64

# GPUのバインディング用ラッパーを作成
cat << 'EOF' > wrapper.sh
#!/bin/bash
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
EOF
chmod +x wrapper.sh

# PPXの計算ノード上限などを考慮して 1, 2, 4 ノードのテストを作成
for NODES in 1 2 4; do
  SCRIPT_NAME="job_ppx_scaling_${NODES}nodes.sh"
  
  # 事前にプロセッサ数を計算しておく
  TOTAL_PROCS=$(( NODES * 4 ))

  cat << IN_EOF > ${SCRIPT_NAME}
#!/bin/bash
#SBATCH -J scale_${NODES}
#SBATCH -N ${NODES}
#SBATCH -p ppx2
#SBATCH --ntasks-per-node=4
#SBATCH -o out/scale_${NODES}nodes_%j.out
#SBATCH -e out/scale_${NODES}nodes_%j.err
#SBATCH -t 00:10:00

module load openmpi

echo "========================================"
echo "Running on ${NODES} nodes"
echo "========================================"

echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_cpu ${N_CPU} ${NODES}

echo "[2/4] N-body GPU (N=${N_GPU})"
mpirun -n ${TOTAL_PROCS} --map-by ppr:4:node --bind-to none ./wrapper.sh ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun -n ${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_cpu ${NX} ${NX} ${NX} ${NODES}

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
mpirun -n ${TOTAL_PROCS} --map-by ppr:4:node --bind-to none ./wrapper.sh ./bin/diffusion_gpu ${NX} ${NX} ${NX} ${NODES}

IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  echo "Generated and submitted ${SCRIPT_NAME}"
  sbatch ${SCRIPT_NAME} 
done
