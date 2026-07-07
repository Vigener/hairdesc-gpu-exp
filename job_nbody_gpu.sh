#!/bin/bash
#PBS -q debug-g
#PBS -l select=1
#PBS -l walltime=00:10:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd ${PBS_O_WORKDIR}

NODES=$(cat ${PBS_NODEFILE} | wc -l)
N=10000

# GPUマッピング用ラッパースクリプト作成
cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
WRAPPER
chmod +x wrapper.sh

echo "Running GPU version on ${NODES} nodes..."
mpiexec -n ${NODES} --map-by ppr:1:node ./wrapper.sh ./bin/nbody_gpu ${N} ${NODES}
