#!/bin/bash
#PBS -q debug-g
#PBS -l select=2
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

# コンパイル確認
make -f Makefile.miyabi build_gpu_fast

# GPU割り当て用ラッパーの作成
cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
WRAPPER
chmod +x wrapper.sh

echo "=== Nsight Systems Profiling: Diffusion3D Async (2 Nodes) ==="
# 10ステップのみ実行してオーバーヘッドを抑える
nsys profile -f true -o nsys_diffusion_async \
  mpiexec -n 2 --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/diffusion_gpu 1024 1024 1024 10

echo "Profiling completed. Please sync 'nsys_diffusion_async.nsys-rep' to your Mac."
