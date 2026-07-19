#!/bin/bash
# submit_nbody_gpu_soa_fastmath.sh
# N=65536, STEPS=100 での GPU SoA Fast Math (Miyabi-G GPU, debug-g) Strong Scaling
# ノード数: 1, 2 を個別ジョブで自動生成して投入

set -euo pipefail

N=65536
STEPS=100

echo "=== N-body GPU SoA Fast Math 性能評価実験 ==="
echo "    N=${N}, STEPS=${STEPS}, ノード数: 1, 2"
echo "    GPU: Miyabi-G GPU (NVIDIA H100, debug-g)"
echo ""

# まず共通でコンパイルを行う (ビルドエラーがある場合はここで即座に落ちるため安全)
make -f Makefile.miyabi build_gpu_soa

for NODES in 1 2; do
  SCRIPT_GPU="job_nbody_gpu_soa_fastmath_${NODES}nodes.sh"
  cat << EOF > ${SCRIPT_GPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}:ncpus=72:mpiprocs=1:ngpus=1
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

# GPU用のラッパースクリプト作成
cat << 'WRAPPER' > wrapper_\${PBS_JOBID}.sh
#!/bin/bash
local_rank=\${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=\${local_rank}
exec "\$@"
WRAPPER
chmod +x wrapper_\${PBS_JOBID}.sh

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./wrapper_\${PBS_JOBID}.sh ./bin/nbody_gpu_soa ${N} \${NODES} ${STEPS}

rm -f wrapper_\${PBS_JOBID}.sh
EOF
  chmod +x ${SCRIPT_GPU}
  echo "Generated: ${SCRIPT_GPU}"
  echo "  -> Submitting GPU SoA Fast Math ${NODES}nodes..."
  qsub ${SCRIPT_GPU}
  echo ""
done

echo "=== 全2ジョブ投入完了 ==="
echo ""
qstat
