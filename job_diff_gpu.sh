#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:10:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# GPUDirect RDMA と CUDA Aware MPI を有効化する
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib
export UCX_MEMTYPE_CACHE=n
export UCX_TLS=rc,cuda_copy,cuda_ipc

NODES=$(cat ${PBS_NODEFILE} | wc -l)
# 1ノードあたり4GPUがあるため、ノード数×4プロセスを立ち上げる
TOTAL_PROCS=$((NODES * 4))
N=256

echo "Running 3D Diffusion GPU version on ${NODES} nodes (${TOTAL_PROCS} GPUs)..."
# 各プロセスにローカルのGPU 0~3を割り当てるラッパースクリプトをインラインで生成
cat << 'EOF' > run_gpu.sh
#!/bin/bash
export CUDA_VISIBLE_DEVICES=${OMPI_COMM_WORLD_LOCAL_RANK}
exec "$@"
EOF
chmod +x run_gpu.sh

mpiexec -n ${TOTAL_PROCS} --map-by ppr:4:node ./run_gpu.sh ./bin/diffusion_gpu ${TOTAL_PROCS} ${N}
