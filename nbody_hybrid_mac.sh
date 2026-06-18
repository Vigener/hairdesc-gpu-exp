#!/bin/bash
#set -euo pipefail

#SBATCH -J nbody_hybrid
#SBATCH -N 4
#SBATCH -p ppx2
#SBATCH -w ppx2-[00-03]
#SBATCH --ntasks=112     # 全ノードの合計コア数（スロット）を最大112として確保
#SBATCH -o out/nbody_hybrid_%j.out

if command -v module >/dev/null 2>&1; then
    module load openmpi
fi

echo "Nodes,MPI_Processes,OpenMP_Threads,NumParticles,Time_sec"

# 実行用のヘルパー関数を定義（引数: ノード数, MPIプロセス数, OMPスレッド数）
run_exp() {
    local nodes=$1
    # --map-by ppr:X:node:PE=N は 1ノードあたりXプロセス、1プロセスあたりNコアを割当
    local procs_per_node=$2
    local omp_threads=$3
    local run_particles=896
    local source_particles=1000
    local data_dir="./grav_data/n${source_particles}"

    export OMP_NUM_THREADS=${omp_threads}
    # -n は全体のMPIプロセス数
    local mpi_procs=$((nodes * procs_per_node))  # 全体のMPIプロセス数

    mpirun -n ${mpi_procs} \
        ${NQSII_MPIOPTS:-} \
        -x OMP_NUM_THREADS \
        --map-by ppr:${procs_per_node}:node:PE=${omp_threads} \
        --bind-to core \
        ./nbody_hybrid \
        ${run_particles} \
        ${nodes} \
        ${data_dir}/m.double \
        ${data_dir}/x.double \
        ${data_dir}/y.double \
        ${data_dir}/z.double \
        ${data_dir}/vx.double \
        ${data_dir}/vy.double \
        ${data_dir}/vz.double
}


# １ノード
run_exp 1 8 1
run_exp 1 4 2
run_exp 1 2 4
run_exp 1 1 8