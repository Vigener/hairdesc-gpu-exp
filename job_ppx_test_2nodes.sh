#!/bin/bash
#SBATCH -J ppx_test
#SBATCH -p ppx2                 # ※GPU用パーティション名が別にある場合は要変更
#SBATCH -N 2
#SBATCH --ntasks-per-node=4
#SBATCH -o out/%j.out
#SBATCH -e out/%j.err
#SBATCH -t 00:10:00

set -euo pipefail
mkdir -p out

# 必須モジュールのロード
module load nvhpc
module load openmpi

echo "========================================"
echo "Running Minimal Test on PPX (2 nodes)"
echo "========================================"

# CPU版テスト (1ノード1プロセスとして実行)
echo "[1/4] N-body CPU (N=1024)"
mpirun --bind-to none -np 2 --map-by ppr:1:node ./bin/nbody_cpu 1024 2

# GPUバインディング用ラッパー
cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
WRAPPER
chmod +x wrapper.sh

# GPU版テスト (ここでPegasus同様にデッドロックするか検証)
echo "[2/4] N-body GPU (N=4096)"
mpirun --bind-to none -np 8 --map-by ppr:4:node ./wrapper.sh ./bin/nbody_gpu 4096 2

echo "[3/4] Diffusion CPU (64x64x64)"
mpirun --bind-to none -np 2 --map-by ppr:1:node ./bin/diffusion_cpu 64 64 64 2

echo "[4/4] Diffusion GPU (64x64x64)"
mpirun --bind-to none -np 8 --map-by ppr:4:node ./wrapper.sh ./bin/diffusion_gpu 64 64 64 2

echo "All tests finished successfully!"
