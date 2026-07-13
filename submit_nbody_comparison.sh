#!/bin/bash
# submit_nbody_comparison.sh
# N=65536, STEPS=100 での CPU (Miyabi-C) vs GPU (Miyabi-G) Strong Scaling
# ノード数: 1, 2 を個別ジョブで投入（ノードの無駄遣いなし）
# 実行前提: submit_nbody_comparison_minimal.sh が正常完走していること

set -euo pipefail

N=65536
STEPS=100

echo "=== N-body CPU vs GPU 性能比較実験 ==="
echo "    N=${N}, STEPS=${STEPS}, ノード数: 1, 2"
echo "    CPU: Miyabi-C (Intel Xeon MAX, short-c)"
echo "    GPU: Miyabi-G (NVIDIA H100, debug-g)"
echo "    出力形式: nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
echo ""

for NODES in 1 2; do

  # --- CPU ジョブ (Miyabi-C, short-c) ---
  SCRIPT_CPU="job_cmp_cpu_${NODES}nodes.sh"
  cat << EOF > ${SCRIPT_CPU}
#!/bin/bash
#PBS -q short-c
#PBS -l select=${NODES}
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
mpiexec.hydra -n \${NODES} ./bin/nbody_cpu_fast ${N} \${NODES} ${STEPS}
EOF
  chmod +x ${SCRIPT_CPU}
  echo "Generated: ${SCRIPT_CPU}"
  echo "  -> Submitting CPU ${NODES}nodes..."
  qsub ${SCRIPT_CPU}

  # --- GPU ジョブ (Miyabi-G, debug-g) ---
  SCRIPT_GPU="job_cmp_gpu_${NODES}nodes.sh"
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

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper.sh ./bin/nbody_gpu_fast ${N} \${NODES} ${STEPS}
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
