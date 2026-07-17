#!/bin/bash
# submit_nbody_comparison_minimal.sh
# 極小サイズ (N=64, STEPS=10) での CPU (Miyabi-G CPU, debug-g) vs GPU (Miyabi-G GPU, debug-g) 動作確認テスト（2ノード）

set -euo pipefail

N=64
STEPS=10
NODES=2

echo "=== 極小サイズ動作確認: N=${N}, STEPS=${STEPS}, ${NODES}ノード ==="
echo "    CPU: Miyabi-G CPU (NVIDIA Grace, debug-g)"
echo "    GPU: Miyabi-G GPU (NVIDIA H100, debug-g)"
echo "    出力形式: nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo ""

# --- CPU ジョブ (Miyabi-G CPU, debug-g) ---
SCRIPT_CPU="job_cmp_minimal_cpu_2nodes.sh"
cat << EOF > ${SCRIPT_CPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

make -f Makefile.miyabi build_cpu_fast

# Grace CPU (72コア)
export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo "CPU_RESULT:"
# コア縛りを解除してマルチスレッドを有効化
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_cpu_fast ${N} \dots \${NODES} ${STEPS}
EOF
# ※注意: 過去の経緯で `./bin/nbody_cpu_fast` の引数は `N nodes steps` だったため、
# `./bin/nbody_cpu_fast ${N} \${NODES} ${STEPS}` とするべきところ、上のテンプレートに \dots を誤って入れてしまわないよう修正します。
# 実際には ./bin/nbody_cpu_fast ${N} \${NODES} ${STEPS} です。

# 正しいCPUジョブテンプレート
cat << EOF > ${SCRIPT_CPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

make -f Makefile.miyabi build_cpu_fast

# Grace CPU (72コア)
export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo "CPU_RESULT:"
# コア縛りを解除してマルチスレッドを有効化
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_cpu_fast ${N} \${NODES} ${STEPS}
EOF
chmod +x ${SCRIPT_CPU}

# --- GPU ジョブ (Miyabi-G GPU, debug-g) ---
SCRIPT_GPU="job_cmp_minimal_gpu_2nodes.sh"
cat << EOF > ${SCRIPT_GPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
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

make -f Makefile.miyabi build_gpu_fast

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo "GPU_RESULT:"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/nbody_gpu_fast ${N} \${NODES} ${STEPS}
EOF
chmod +x ${SCRIPT_GPU}

echo "Generated: ${SCRIPT_CPU}"
echo "Generated: ${SCRIPT_GPU}"
echo ""
echo "Submitting CPU job (Miyabi-G CPU, 2 nodes)..."
qsub ${SCRIPT_CPU}
echo "Submitting GPU job (Miyabi-G GPU, 2 nodes)..."
qsub ${SCRIPT_GPU}
echo ""
echo "Check status: qstat"
qstat
