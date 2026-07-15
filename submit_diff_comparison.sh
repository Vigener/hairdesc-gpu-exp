#!/bin/bash
# submit_diff_comparison.sh
# NX=1024, STEPS=100 での CPU (Miyabi-G CPU, debug-g) vs GPU (Miyabi-G GPU, debug-g) Strong Scaling 性能比較
# ノード数: 1, 2 を個別ジョブで投入

set -euo pipefail

NX=1024
STEPS=100

echo "=== Diffusion3D CPU vs GPU 性能比較実験 ==="
echo "    NX=${NX}, STEPS=${STEPS}, ノード数: 1, 2"
echo "    CPU: Miyabi-G CPU (NVIDIA Grace, debug-g)"
echo "    GPU: Miyabi-G GPU (NVIDIA H100, debug-g)"
echo "    出力形式: nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS,BW(GB/s)"
echo ""

for NODES in 1 2; do

  # --- CPU ジョブ (Miyabi-G CPU, debug-g) ---
  SCRIPT_CPU="job_diff_cmp_cpu_${NODES}nodes.sh"
  cat << EOF > ${SCRIPT_CPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

make -f Makefile.miyabi build_diff_cpu

# Grace CPU (72コア)
export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS,BW(GB/s)"
# コア縛りを解除してマルチスレッドを有効化
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_cpu \${NODES} ${NX} ${STEPS}
EOF
  chmod +x ${SCRIPT_CPU}
  echo "Generated: ${SCRIPT_CPU}"
  echo "  -> Submitting CPU ${NODES}nodes (Miyabi-G CPU)..."
  qsub ${SCRIPT_CPU}

  # --- GPU ジョブ (Miyabi-G GPU, debug-g) ---
  SCRIPT_GPU="job_diff_cmp_gpu_${NODES}nodes.sh"
  cat << EOF > ${SCRIPT_GPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

# GPUDirect RDMA と CUDA Aware MPI を有効化
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib
export UCX_MEMTYPE_CACHE=n
export UCX_TLS=rc,cuda_copy,cuda_ipc

cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=\${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=\${local_rank}
exec "\$@"
WRAPPER
chmod +x wrapper.sh

make -f Makefile.miyabi build_diff_gpu

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS,BW(GB/s)"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/diffusion_gpu \dots \${NODES} ${NX} ${STEPS}
EOF
  # wrapper.sh の引数指定ミスがないように修正 ( \dots などのゴミが入らないようにする )
  # 正しいコマンド: ./wrapper.sh ./bin/diffusion_gpu \${NODES} ${NX} ${STEPS}
  # 上記コードブロックの mpiexec の引数の \dots を削除して修正
  
  # 修正したスクリプト内容で上書きします
  cat << EOF > ${SCRIPT_GPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

# GPUDirect RDMA と CUDA Aware MPI を有効化
export OMPI_MCA_pml=ucx
export OMPI_MCA_btl=^openib
export UCX_MEMTYPE_CACHE=n
export UCX_TLS=rc,cuda_copy,cuda_ipc

cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=\${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=\${local_rank}
exec "\$@"
WRAPPER
chmod +x wrapper.sh

make -f Makefile.miyabi build_diff_gpu

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS,BW(GB/s)"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/diffusion_gpu \${NODES} ${NX} ${STEPS}
EOF
  chmod +x ${SCRIPT_GPU}
  echo "Generated: ${SCRIPT_GPU}"
  echo "  -> Submitting GPU ${NODES}nodes..."
  qsub ${SCRIPT_GPU}

  echo ""
done

echo "=== 全4ジョブ投入完了 ==="
echo ""
qstat
