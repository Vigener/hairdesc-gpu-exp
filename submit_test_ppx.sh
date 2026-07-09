#!/bin/bash
#set -euo pipefail

#SBATCH -J ppx_test
#SBATCH -N 2
#SBATCH -p ppx2
#SBATCH --ntasks-per-node=4
#SBATCH -o out/ppx_test_%j.out
#SBATCH -e out/ppx_test_%j.err
#SBATCH -t 00:10:00

module load openmpi
# module load nvhpc はPPXに存在しないため削除しました。
# GPUコンパイルが成功している場合は、nvc++が既定のパスに通っている前提で実行します。

echo "========================================"
echo "Running Minimal Test on PPX (2 nodes)"
echo "========================================"

N_CPU=1024
N_GPU=4096
NX=64
TOTAL_PROCS=$(( 2 * 4 ))

# GPUバインディング用ラッパーを作成
cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
WRAPPER
chmod +x wrapper.sh

echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun -n 2 \
    --map-by ppr:1:node \
    --bind-to none \
    ./bin/nbody_cpu ${N_CPU} 2

echo "[2/4] N-body GPU (N=${N_GPU})"
mpirun -n ${TOTAL_PROCS} \
    --map-by ppr:4:node \
    --bind-to none \
    ./wrapper.sh ./bin/nbody_gpu ${N_GPU} 2

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun -n 2 \
    --map-by ppr:1:node \
    --bind-to none \
    ./bin/diffusion_cpu ${NX} ${NX} ${NX} 2

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
mpirun -n ${TOTAL_PROCS} \
    --map-by ppr:4:node \
    --bind-to none \
    ./wrapper.sh ./bin/diffusion_gpu ${NX} ${NX} ${NX} 2

echo "All tests finished successfully!"
