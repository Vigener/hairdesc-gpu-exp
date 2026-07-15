#!/bin/bash
# submit_diff_comparison_minimal.sh
# N=64, STEPS=10 での CPU (Miyabi-G CPU, debug-g) vs GPU (Miyabi-G GPU, debug-g) 動作確認テスト（2ノード）

set -euo pipefail

N=64
STEPS=10
NODES=2

echo "=== Diffusion3D CPU vs GPU 動作確認テスト (極小サイズ) ==="
echo "    N=${N}, STEPS=${STEPS}, ノード数: ${NODES}"
echo "    CPU: Miyabi-G CPU (NVIDIA Grace, debug-g)"
echo "    GPU: Miyabi-G GPU (NVIDIA H100, debug-g)"
echo "    出力形式: nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS,BW(GB/s)"
echo ""

# --- CPU ジョブ (Miyabi-G CPU, debug-g) ---
SCRIPT_CPU="job_diff_cmp_minimal_cpu.sh"
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
# 1ノードあたり1MPIプロセスとし、コア縛りを解除してマルチスレッドを有効化
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./bin/diffusion_cpu \${NODES} ${N} ${STEPS}
EOF
chmod +x ${SCRIPT_CPU}
echo "Generated: ${SCRIPT_CPU}"
echo "  -> Submitting CPU minimal (Miyabi-G CPU)..."
qsub ${SCRIPT_CPU}

# --- GPU ジョブ (Miyabi-G GPU, debug-g) ---
SCRIPT_GPU="job_diff_cmp_minimal_gpu.sh"
cat << EOF > ${SCRIPT_GPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

# GPUDirect RDMA と CUDA Aware MPI を有効化する
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
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/diffusion_gpu \${NODES} ${N} ${STEPS}
EOF
chmod +x ${SCRIPT_GPU}
echo "Generated: ${SCRIPT_GPU}"
echo "  -> Submitting GPU minimal..."
qsub ${SCRIPT_GPU}

echo ""
qstat
