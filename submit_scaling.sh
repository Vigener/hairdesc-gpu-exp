#!/bin/bash

# N-bodyではプロセス数で割り切れる必要があるため、128の倍数に設定
# CPU用: 最小限のテストサイズ (128の倍数) -> 1024
# GPU用: 最小限のテストサイズ (128の倍数) -> 4096
N_CPU=1024
N_GPU=4096
NX=64

# GPUのバインディング用ラッパーを作成
cat << 'EOF' > wrapper.sh
#!/bin/bash
export CUDA_VISIBLE_DEVICES=${OMPI_COMM_WORLD_LOCAL_RANK}
exec "$@"
EOF
chmod +x wrapper.sh

for NODES in 1 2 4 8 16 32; do
  SCRIPT_NAME="job_pegasus_${NODES}nodes.sh"
  
  # 事前にプロセッサ数を計算しておく（Heredoc内で展開させるため）
  TOTAL_PROCS=$(( NODES * 4 ))

  cat << IN_EOF > ${SCRIPT_NAME}
#!/bin/bash
#PBS -q gpu
#PBS -A QHPC
#PBS -b ${NODES}
#PBS -l elapstim_req=00:15:00
#PBS -T openmpi
#PBS -v NQSV_MPI_VER="nvhpc-hpcx-cuda13/25.11"

cd \${PBS_O_WORKDIR}
# nvhpc-nompi と openmpi は競合するため、単独で openmpi をロードする（内部でNVHPCが含まれる）
module purge
module load openmpi/nvhpc-hpcx-cuda13/25.11

# Managed Memory (Unified Memory) をMPI通信する際のUCX(OpenMPI)のハングアップを回避する設定
export UCX_MEMTYPE_CACHE=n
export OMPI_MCA_opal_cuda_support=0

echo "========================================"
echo "Running on ${NODES} nodes"
echo "========================================"

echo "[1/4] N-body CPU (N=${N_CPU})"
mpirun \${NQSV_MPIOPTS} --bind-to none -np ${NODES} -npernode 1 ./bin/nbody_cpu ${N_CPU} ${NODES}

echo "[2/4] N-body GPU (N=${N_GPU})"
mpirun \${NQSV_MPIOPTS} --bind-to none -np ${TOTAL_PROCS} -npernode 4 ./wrapper.sh ./bin/nbody_gpu ${N_GPU} ${NODES}

echo "[3/4] Diffusion CPU (${NX}x${NX}x${NX})"
mpirun \${NQSV_MPIOPTS} --bind-to none -np ${NODES} -npernode 1 ./bin/diffusion_cpu ${NX} ${NX} ${NX} ${NODES}

echo "[4/4] Diffusion GPU (${NX}x${NX}x${NX})"
mpirun \${NQSV_MPIOPTS} --bind-to none -np ${TOTAL_PROCS} -npernode 4 ./wrapper.sh ./bin/diffusion_gpu ${NX} ${NX} ${NX} ${NODES}

IN_EOF
  
  chmod +x ${SCRIPT_NAME}
  echo "Generated ${SCRIPT_NAME}"
done
