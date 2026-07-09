#!/bin/bash

# Miyabi専用の最小疎通確認用ジョブ作成スクリプト
# 2ノード限定、極小問題サイズでMPI通信のデッドロックが起きないかをテストします

N_CPU=1024
N_GPU=4096
NX=64
NODES=2
TOTAL_PROCS=${NODES} # Miyabi-G (GH200)は1ノードにつき1 GPUなので、ノード数=プロセス数

SCRIPT_NAME="job_miyabi_test_2nodes.sh"

cat << IN_EOF > ${SCRIPT_NAME}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:10:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

echo "========================================"
echo "Running Minimal Test on Miyabi-G (${NODES} nodes)"
echo "========================================"

# CPU版テスト
echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun -n ${NODES} --map-by ppr:1:node ./bin/nbody_cpu ${N_CPU} ${NODES}

# GPUバインディング用ラッパー
cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=\${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=\${local_rank}
exec "\$@"
WRAPPER
chmod +x wrapper.sh

# GPU版テスト (GH200のUnified Memoryを扱うためここでデッドロックするか検証)
echo "[2/4] N-body GPU (N=${N_GPU})"
mpirun -n ${TOTAL_PROCS} --map-by ppr:1:node ./wrapper.sh ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun -n ${NODES} --map-by ppr:1:node ./bin/diffusion_cpu ${NX} ${NX} ${NX} ${NODES}

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
mpirun -n ${TOTAL_PROCS} --map-by ppr:1:node ./wrapper.sh ./bin/diffusion_gpu ${NX} ${NX} ${NX} ${NODES}

echo "All tests finished successfully!"
IN_EOF

chmod +x ${SCRIPT_NAME}
echo "Generated ${SCRIPT_NAME}"
echo "To run on Miyabi, execute: qsub ${SCRIPT_NAME}"
