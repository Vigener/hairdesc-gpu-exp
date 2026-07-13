#!/bin/bash
# submit_nbody_comparison_minimal.sh
# 極小サイズ (N=64, STEPS=10) での CPU vs GPU 動作確認スクリプト
# ルール: まず2ノードでデッドロックしないことを確認する

set -euo pipefail

N=64
STEPS=10
WORKDIR=/work/xg26i048/x10752/projects/hairdesc-gpu-exp

echo "=== 極小サイズ動作確認: N=${N}, STEPS=${STEPS}, 2ノード ==="
echo ""

# --- CPU (Miyabi-C, 2ノード) ---
SCRIPT_CPU="job_cmp_minimal_cpu_2nodes.sh"
cat << EOF > ${SCRIPT_CPU}
#!/bin/bash
#PBS -q short-c
#PBS -l select=2
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

make -f Makefile.miyabi-c build_cpu_fast

export OMP_NUM_THREADS=112
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo "CPU_RESULT:"
mpiexec.hydra -n \${NODES} ./bin/nbody_cpu_fast ${N} \${NODES} ${STEPS}
EOF
chmod +x ${SCRIPT_CPU}

# --- GPU (Miyabi-G, 2ノード) ---
SCRIPT_GPU="job_cmp_minimal_gpu_2nodes.sh"
cat << EOF > ${SCRIPT_GPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=2
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

cat << 'WRAPPER' > wrapper.sh
#!/bin/bash
local_rank=\${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=\${local_rank}
exec "\$@"
WRAPPER
chmod +x wrapper.sh

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo "GPU_RESULT:"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/nbody_gpu_fast ${N} \${NODES} ${STEPS}
EOF
chmod +x ${SCRIPT_GPU}

echo "Generated: ${SCRIPT_CPU}"
echo "Generated: ${SCRIPT_GPU}"
echo ""
echo "Submitting CPU job (Miyabi-C, 2 nodes)..."
qsub ${SCRIPT_CPU}
echo "Submitting GPU job (Miyabi-G, 2 nodes)..."
qsub ${SCRIPT_GPU}
echo ""
echo "Check status: qstat"
qstat
