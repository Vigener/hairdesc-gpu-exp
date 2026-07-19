#!/bin/bash
# submit_nbody_cpu_soa.sh
# N=65536, STEPS=100 での CPU SoA (Miyabi-G CPU, debug-g) Strong Scaling
# ノード数: 1, 2 を個別ジョブで自動生成して投入

set -euo pipefail

N=65536
STEPS=100

echo "=== N-body CPU SoA 性能評価実験 ==="
echo "    N=${N}, STEPS=${STEPS}, ノード数: 1, 2"
echo "    CPU: Miyabi-G CPU (NVIDIA Grace, debug-g)"
echo ""

# まず共通でコンパイルを行う (ビルドエラーがある場合はここで即座に落ちるため安全)
make -f Makefile.miyabi build_cpu_soa

for NODES in 1 2; do
  SCRIPT_CPU="job_nbody_cpu_soa_${NODES}nodes.sh"
  cat << EOF > ${SCRIPT_CPU}
#!/bin/bash
#PBS -q debug-g
#PBS -l select=${NODES}
#PBS -l walltime=00:03:00
#PBS -W group_list=xg26i048
#PBS -j oe

set -euo pipefail
cd \${PBS_O_WORKDIR}

# Grace CPU (72コア)
export OMP_NUM_THREADS=72
export OMP_PROC_BIND=close
export OMP_PLACES=cores

NODES=\$(cat \${PBS_NODEFILE} | wc -l)
echo "# nodes,mpi_procs,omp_threads,N,steps,time(s),GFLOPS"
mpiexec -n \${NODES} --map-by ppr:1:node --bind-to none ./bin/nbody_cpu_soa ${N} \${NODES} ${STEPS}
EOF
  chmod +x ${SCRIPT_CPU}
  echo "Generated: ${SCRIPT_CPU}"
  echo "  -> Submitting CPU SoA ${NODES}nodes..."
  qsub ${SCRIPT_CPU}
  echo ""
done

echo "=== 全2ジョブ投入完了 ==="
echo ""
qstat
